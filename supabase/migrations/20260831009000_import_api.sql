create table if not exists app_private.import_commit_receipts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_private.user_profiles (user_id) on delete cascade,
    idempotency_key uuid not null,
    response jsonb not null,
    created_at timestamptz not null default timezone('utc', now()),
    unique (user_id, idempotency_key)
);

alter table app_private.import_commit_receipts enable row level security;

create policy import_commit_receipts_select_own
on app_private.import_commit_receipts
for select
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy import_commit_receipts_insert_own
on app_private.import_commit_receipts
for insert
to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create or replace function api.v1_list_import_batches()
returns table (
    id uuid,
    source_filename text,
    account_id uuid,
    row_count integer,
    imported_at timestamptz,
    created_at timestamptz,
    updated_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
    select
        batch.id,
        batch.source_filename,
        batch.account_id,
        batch.row_count,
        batch.imported_at,
        batch.created_at,
        batch.updated_at
    from app_private.import_batches batch
    where batch.user_id = auth.uid()
    order by batch.imported_at desc, batch.created_at desc, batch.id desc
$$;

create or replace function app_private.v1_import_commit_prepare(
    p_user_id uuid,
    p_batches jsonb,
    p_transactions jsonb
)
returns text
language plpgsql
security definer
set search_path = app_private, extensions
as $$
begin
    create temporary table pg_temp.import_batch_input (
        batch_id uuid primary key,
        source_filename text not null,
        account_id uuid not null,
        imported_at timestamptz not null,
        import_format text not null
    ) on commit drop;

    insert into pg_temp.import_batch_input (
        batch_id, source_filename, account_id, imported_at, import_format
    )
    select
        batch_row.batch_id, batch_row.source_filename, batch_row.account_id, batch_row.imported_at, batch_row.import_format
    from jsonb_to_recordset(coalesce(p_batches, '[]'::jsonb)) as batch_row(
        batch_id uuid,
        source_filename text,
        account_id uuid,
        imported_at timestamptz,
        import_format text
    );

    create temporary table pg_temp.import_transaction_input (
        transaction_id uuid primary key,
        batch_id uuid not null,
        category_slug text not null,
        subcategory_id uuid,
        amount_cents bigint not null,
        occurred_at timestamptz not null,
        origin_occurred_at timestamptz,
        purchase_type text,
        installment_index integer,
        installment_count integer,
        description text not null,
        notes text,
        external_id text
    ) on commit drop;

    insert into pg_temp.import_transaction_input (
        transaction_id, batch_id, category_slug, subcategory_id, amount_cents,
        occurred_at, origin_occurred_at, purchase_type, installment_index, installment_count,
        description, notes, external_id
    )
    select
        tx_row.transaction_id, tx_row.batch_id, tx_row.category_slug, tx_row.subcategory_id, tx_row.amount_cents,
        tx_row.occurred_at, tx_row.origin_occurred_at, tx_row.purchase_type, tx_row.installment_index, tx_row.installment_count,
        tx_row.description, tx_row.notes, tx_row.external_id
    from jsonb_to_recordset(coalesce(p_transactions, '[]'::jsonb)) as tx_row(
        transaction_id uuid,
        batch_id uuid,
        category_slug text,
        subcategory_id uuid,
        amount_cents bigint,
        occurred_at timestamptz,
        origin_occurred_at timestamptz,
        purchase_type text,
        installment_index integer,
        installment_count integer,
        description text,
        notes text,
        external_id text
    );

    if exists (
        select 1
        from pg_temp.import_transaction_input tx
        left join pg_temp.import_batch_input batch on batch.batch_id = tx.batch_id
        where batch.batch_id is null
    ) then
        return 'unexpected_response';
    end if;

    if exists (
        select 1
        from pg_temp.import_transaction_input tx
        join pg_temp.import_batch_input batch on batch.batch_id = tx.batch_id
        left join app_private.accounts account
            on account.user_id = p_user_id
           and account.id = batch.account_id
        where account.id is null
    ) then
        return 'invalid_account';
    end if;

    if exists (
        select 1
        from pg_temp.import_batch_input batch
        join app_private.accounts account
            on account.user_id = p_user_id
           and account.id = batch.account_id
        left join app_private.supported_institutions_catalog institution
            on institution.id = account.institution_id
        where institution.id is null
           or not (batch.import_format = any(institution.supported_import_formats))
    ) then
        return 'unsupported_import_format';
    end if;

    create temporary table pg_temp.import_resolved_transaction (
        transaction_id uuid primary key,
        batch_id uuid not null,
        account_id uuid not null,
        category_id uuid not null,
        subcategory_id uuid,
        amount_cents bigint not null,
        occurred_at timestamptz not null,
        origin_occurred_at timestamptz not null,
        purchase_type text,
        installment_index integer,
        installment_count integer,
        description text not null,
        notes text,
        external_id text
    ) on commit drop;

    insert into pg_temp.import_resolved_transaction (
        transaction_id, batch_id, account_id, category_id, subcategory_id, amount_cents,
        occurred_at, origin_occurred_at, purchase_type, installment_index, installment_count,
        description, notes, external_id
    )
    select
        tx.transaction_id, tx.batch_id, batch.account_id, category.id, tx.subcategory_id, tx.amount_cents,
        tx.occurred_at, coalesce(tx.origin_occurred_at, tx.occurred_at),
        nullif(trim(coalesce(tx.purchase_type, '')), ''), tx.installment_index, tx.installment_count,
        trim(tx.description), nullif(trim(coalesce(tx.notes, '')), ''), nullif(trim(coalesce(tx.external_id, '')), '')
    from pg_temp.import_transaction_input tx
    join pg_temp.import_batch_input batch on batch.batch_id = tx.batch_id
    join app_private.category_catalog category
        on category.parent_id is null
       and category.slug = tx.category_slug;

    if (select count(*) from pg_temp.import_resolved_transaction)
       <> (select count(*) from pg_temp.import_transaction_input)
    then
        return 'invalid_category';
    end if;

    if exists (
        select 1
        from pg_temp.import_resolved_transaction tx
        where tx.amount_cents <= 0
           or length(trim(tx.description)) = 0
           or (tx.purchase_type is not null and tx.purchase_type not in ('cash', 'installment'))
    ) then
        return 'unexpected_response';
    end if;

    if exists (
        select 1
        from pg_temp.import_resolved_transaction tx
        where tx.subcategory_id is not null
          and not exists (
              select 1
              from app_private.category_catalog subcategory
              where subcategory.id = tx.subcategory_id
                and subcategory.parent_id = tx.category_id
          )
    ) then
        return 'invalid_subcategory';
    end if;

    if exists (
        select 1
        from pg_temp.import_resolved_transaction tx
        where not (
            (tx.purchase_type is null and tx.installment_index is null and tx.installment_count is null)
            or (tx.purchase_type = 'cash' and tx.installment_index is null and tx.installment_count is null)
            or (
                tx.purchase_type = 'installment'
                and tx.installment_index is not null
                and tx.installment_count is not null
                and tx.installment_index >= 1
                and tx.installment_count >= 2
                and tx.installment_index <= tx.installment_count
            )
        )
    ) then
        return 'unexpected_response';
    end if;

    return null;
end;
$$;

create or replace function app_private.v1_import_commit_expand_and_dedupe(
    p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = app_private, extensions
as $$
begin
    create temporary table pg_temp.import_expanded_transaction (
        transaction_id uuid primary key,
        batch_id uuid not null,
        account_id uuid not null,
        category_id uuid not null,
        subcategory_id uuid,
        amount_cents bigint not null,
        occurred_at timestamptz not null,
        origin_occurred_at timestamptz not null,
        purchase_type text,
        installment_index integer,
        installment_count integer,
        description text not null,
        notes text,
        external_id text
    ) on commit drop;

    insert into pg_temp.import_expanded_transaction (
        transaction_id, batch_id, account_id, category_id, subcategory_id, amount_cents,
        occurred_at, origin_occurred_at, purchase_type, installment_index, installment_count,
        description, notes, external_id
    )
    select
        case
            when expanded.installment_index is not distinct from tx.installment_index then tx.transaction_id
            else gen_random_uuid()
        end,
        tx.batch_id, tx.account_id, tx.category_id, tx.subcategory_id, tx.amount_cents,
        expanded.occurred_at, expanded.origin_occurred_at, expanded.purchase_type,
        expanded.installment_index, expanded.installment_count,
        tx.description, expanded.notes, expanded.external_id
    from pg_temp.import_resolved_transaction tx
    cross join lateral app_private.v1_import_commit_expand_rows(
        p_user_id,
        tx.account_id,
        tx.origin_occurred_at,
        tx.occurred_at,
        tx.purchase_type,
        tx.installment_index,
        tx.installment_count,
        tx.description,
        tx.notes,
        tx.external_id,
        tx.amount_cents
    ) expanded;

    create temporary table pg_temp.import_duplicate_row (
        batch_id uuid not null,
        external_id text not null,
        description text not null,
        occurred_at timestamptz not null
    ) on commit drop;

    insert into pg_temp.import_duplicate_row (
        batch_id, external_id, description, occurred_at
    )
    select tx.batch_id, tx.external_id, tx.description, tx.occurred_at
    from (
        select
            resolved.*,
            row_number() over (
                partition by resolved.account_id, resolved.external_id
                order by resolved.occurred_at asc, resolved.transaction_id asc
            ) as duplicate_rank
        from pg_temp.import_expanded_transaction resolved
        where resolved.external_id is not null
    ) tx
    where tx.duplicate_rank > 1;

    insert into pg_temp.import_duplicate_row (
        batch_id, external_id, description, occurred_at
    )
    select tx.batch_id, tx.external_id, tx.description, tx.occurred_at
    from pg_temp.import_expanded_transaction tx
    where tx.external_id is not null
      and exists (
          select 1
          from app_private.transactions existing
          where existing.user_id = p_user_id
            and existing.account_id = tx.account_id
            and existing.external_id = tx.external_id
      );

    create temporary table pg_temp.import_insertable_transaction (
        transaction_id uuid primary key,
        batch_id uuid not null,
        account_id uuid not null,
        category_id uuid not null,
        subcategory_id uuid,
        amount_cents bigint not null,
        occurred_at timestamptz not null,
        origin_occurred_at timestamptz not null,
        purchase_type text,
        installment_index integer,
        installment_count integer,
        description text not null,
        notes text,
        external_id text
    ) on commit drop;

    insert into pg_temp.import_insertable_transaction (
        transaction_id, batch_id, account_id, category_id, subcategory_id, amount_cents,
        occurred_at, origin_occurred_at, purchase_type, installment_index, installment_count,
        description, notes, external_id
    )
    select
        tx.transaction_id, tx.batch_id, tx.account_id, tx.category_id, tx.subcategory_id, tx.amount_cents,
        tx.occurred_at, tx.origin_occurred_at, tx.purchase_type, tx.installment_index, tx.installment_count,
        tx.description, tx.notes, tx.external_id
    from pg_temp.import_expanded_transaction tx
    where not exists (
        select 1
        from pg_temp.import_duplicate_row duplicate_row
        where duplicate_row.batch_id = tx.batch_id
          and duplicate_row.external_id = tx.external_id
          and duplicate_row.occurred_at = tx.occurred_at
          and duplicate_row.description = tx.description
    );
end;
$$;

create or replace function app_private.v1_import_commit_persist(
    p_user_id uuid,
    p_idempotency_key uuid,
    p_now timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = app_private, extensions
as $$
declare
    v_account_id uuid;
    v_response jsonb;
begin
    insert into app_private.import_batches (
        id, user_id, source_filename, account_id, row_count, imported_at, created_at, updated_at
    )
    select
        batch.batch_id, p_user_id, batch.source_filename, batch.account_id, count(tx.transaction_id)::integer,
        batch.imported_at, p_now, p_now
    from pg_temp.import_batch_input batch
    join pg_temp.import_insertable_transaction tx on tx.batch_id = batch.batch_id
    group by batch.batch_id, batch.source_filename, batch.account_id, batch.imported_at;

    insert into app_private.transactions (
        id, user_id, account_id, category_id, subcategory_id, amount_cents,
        occurred_at, origin_occurred_at, purchase_type, installment_index, installment_count,
        description, notes, import_batch_id, external_id, created_at, updated_at
    )
    select
        tx.transaction_id, p_user_id, tx.account_id, tx.category_id, tx.subcategory_id, tx.amount_cents,
        tx.occurred_at, tx.origin_occurred_at, tx.purchase_type, tx.installment_index, tx.installment_count,
        tx.description, tx.notes, tx.batch_id, tx.external_id, p_now, p_now
    from pg_temp.import_insertable_transaction tx
    order by tx.occurred_at asc, tx.transaction_id asc;

    for v_account_id in
        select distinct tx.account_id
        from pg_temp.import_insertable_transaction tx
        where app_private.v1_is_credit_card_account(p_user_id, tx.account_id)
    loop
        perform app_private.v1_rebuild_card_statements(p_user_id, v_account_id, p_now);
    end loop;

    v_response := jsonb_build_object(
        'ok', true,
        'code', null,
        'imported_batch_ids', coalesce(
            (
                select jsonb_agg(batch.id order by batch.imported_at desc, batch.id desc)
                from app_private.import_batches batch
                where batch.user_id = p_user_id
                  and exists (
                      select 1
                      from pg_temp.import_batch_input input_batch
                      where input_batch.batch_id = batch.id
                  )
            ),
            '[]'::jsonb
        ),
        'imported_row_count', coalesce((select count(*) from pg_temp.import_insertable_transaction), 0),
        'duplicate_rows', coalesce(
            (
                select jsonb_agg(
                    jsonb_build_object(
                        'batch_id', duplicate_row.batch_id,
                        'external_id', duplicate_row.external_id,
                        'description', duplicate_row.description,
                        'occurred_at', duplicate_row.occurred_at
                    )
                    order by duplicate_row.occurred_at desc, duplicate_row.external_id asc
                )
                from (
                    select distinct row.batch_id, row.external_id, row.description, row.occurred_at
                    from pg_temp.import_duplicate_row row
                ) duplicate_row
            ),
            '[]'::jsonb
        )
    );

    insert into app_private.import_commit_receipts (
        user_id, idempotency_key, response, created_at
    ) values (
        p_user_id, p_idempotency_key, v_response, p_now
    )
    on conflict (user_id, idempotency_key) do update
    set response = excluded.response;

    return v_response;
end;
$$;

create or replace function api.v1_commit_import(
    p_idempotency_key uuid,
    p_batches jsonb,
    p_transactions jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = api, app_private, extensions
as $$
declare
    v_user_id uuid := auth.uid();
    v_now timestamptz := timezone('utc', now());
    v_response jsonb;
    v_code text;
begin
    if v_user_id is null then
        return jsonb_build_object('ok', false, 'code', 'authentication_required');
    end if;

    select receipt.response
    into v_response
    from app_private.import_commit_receipts receipt
    where receipt.user_id = v_user_id
      and receipt.idempotency_key = p_idempotency_key;

    if v_response is not null then
        return v_response;
    end if;

    v_code := app_private.v1_import_commit_prepare(v_user_id, p_batches, p_transactions);
    if v_code is not null then
        return jsonb_build_object('ok', false, 'code', v_code);
    end if;

    perform app_private.v1_import_commit_expand_and_dedupe(v_user_id);
    return app_private.v1_import_commit_persist(v_user_id, p_idempotency_key, v_now);
exception
    when others then
        v_code := sqlerrm;
        if v_code = 'unapplied_payment' then
            return jsonb_build_object('ok', false, 'code', v_code);
        end if;
        raise;
end;
$$;

create or replace function api.v1_delete_import_batch(
    p_batch_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = api, app_private, extensions
as $$
declare
    v_user_id uuid := auth.uid();
    v_now timestamptz := timezone('utc', now());
    v_account_id uuid;
begin
    if v_user_id is null then
        return jsonb_build_object('ok', false, 'code', 'authentication_required');
    end if;

    if not exists (
        select 1
        from app_private.import_batches batch
        where batch.user_id = v_user_id
          and batch.id = p_batch_id
    ) then
        return jsonb_build_object('ok', false, 'code', 'import_batch_not_found');
    end if;

    create temporary table pg_temp.import_batch_account (
        account_id uuid primary key
    ) on commit drop;

    insert into pg_temp.import_batch_account (account_id)
    select distinct tx.account_id
    from app_private.transactions tx
    where tx.user_id = v_user_id
      and tx.import_batch_id = p_batch_id;

    delete from app_private.transactions
    where user_id = v_user_id
      and import_batch_id = p_batch_id;

    delete from app_private.import_batches
    where user_id = v_user_id
      and id = p_batch_id;

    for v_account_id in
        select account_id
        from pg_temp.import_batch_account
        where app_private.v1_is_credit_card_account(v_user_id, account_id)
    loop
        perform app_private.v1_rebuild_card_statements(v_user_id, v_account_id, v_now);
    end loop;

    return jsonb_build_object('ok', true, 'code', null);
end;
$$;

revoke insert, update, delete on table app_private.import_batches from authenticated;
revoke all on function api.v1_list_import_batches() from public;
revoke all on function api.v1_list_import_batches() from anon;
revoke all on function api.v1_list_import_batches() from authenticated;
revoke all on function api.v1_commit_import(uuid, jsonb, jsonb) from public;
revoke all on function api.v1_commit_import(uuid, jsonb, jsonb) from anon;
revoke all on function api.v1_commit_import(uuid, jsonb, jsonb) from authenticated;
revoke all on function api.v1_delete_import_batch(uuid) from public;
revoke all on function api.v1_delete_import_batch(uuid) from anon;
revoke all on function api.v1_delete_import_batch(uuid) from authenticated;

grant execute on function api.v1_list_import_batches() to authenticated;
grant execute on function api.v1_commit_import(uuid, jsonb, jsonb) to authenticated;
grant execute on function api.v1_delete_import_batch(uuid) to authenticated;
