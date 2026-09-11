create extension if not exists pgcrypto with schema extensions;

alter table app_private.transactions
    add column if not exists dedup_key text;

create or replace function app_private.v1_transaction_dedup_key(
    p_account_id uuid,
    p_amount_cents bigint,
    p_description text,
    p_purchase_type text,
    p_installment_index integer,
    p_installment_count integer,
    p_origin_occurred_at timestamptz
)
returns text
language sql
stable
set search_path = app_private, extensions
as $$
    select encode(
        extensions.digest(
            format(
                '{"v":1,"account_id":%s,"amount_cents":%s,"description":%s,"purchase_type":%s,"installment_index":%s,"installment_count":%s,"origin_occurred_at":%s}',
                to_json(lower(p_account_id::text))::text,
                p_amount_cents::text,
                to_json(p_description)::text,
                coalesce(to_json(p_purchase_type)::text, 'null'),
                coalesce(p_installment_index::text, 'null'),
                coalesce(p_installment_count::text, 'null'),
                to_json(to_char(
                    p_origin_occurred_at at time zone 'UTC',
                    'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
                ))::text
            ),
            'sha256'
        ),
        'hex'
    );
$$;

update app_private.transactions
set dedup_key = app_private.v1_transaction_dedup_key(
    account_id,
    amount_cents,
    description,
    purchase_type,
    installment_index,
    installment_count,
    origin_occurred_at
)
where dedup_key is null;

alter table app_private.transactions
    alter column dedup_key set not null;

create index if not exists transactions_user_account_dedup_key_idx
    on app_private.transactions (user_id, account_id, dedup_key);

drop function if exists api.v1_list_transactions(integer, timestamptz, timestamptz, uuid);

create function api.v1_list_transactions(
    p_limit integer default 51,
    p_after_occurred_at timestamptz default null,
    p_after_created_at timestamptz default null,
    p_after_id uuid default null
)
returns table (
    id uuid,
    account_id uuid,
    category_id uuid,
    subcategory_id uuid,
    amount_cents bigint,
    occurred_at timestamptz,
    origin_occurred_at timestamptz,
    purchase_type text,
    installment_index integer,
    installment_count integer,
    description text,
    notes text,
    import_batch_id uuid,
    dedup_key text,
    external_id text,
    destination_account_id uuid,
    statement_id uuid,
    created_at timestamptz,
    updated_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
    select
        t.id,
        t.account_id,
        t.category_id,
        t.subcategory_id,
        t.amount_cents,
        t.occurred_at,
        t.origin_occurred_at,
        t.purchase_type,
        t.installment_index,
        t.installment_count,
        t.description,
        t.notes,
        t.import_batch_id,
        t.dedup_key,
        t.external_id,
        t.destination_account_id,
        t.statement_id,
        t.created_at,
        t.updated_at
    from app_private.transactions t
    where t.user_id = auth.uid()
      and (
        p_after_occurred_at is null
        or t.occurred_at < p_after_occurred_at
        or (
            t.occurred_at = p_after_occurred_at
            and t.created_at < p_after_created_at
        )
        or (
            t.occurred_at = p_after_occurred_at
            and t.created_at = p_after_created_at
            and t.id < p_after_id
        )
      )
    order by t.occurred_at desc, t.created_at desc, t.id desc
    limit greatest(1, least(coalesce(p_limit, 51), 201));
$$;

create or replace function api.v1_create_transaction(
    p_account_id uuid,
    p_category_id uuid,
    p_subcategory_id uuid,
    p_amount_cents bigint,
    p_occurred_at timestamptz,
    p_origin_occurred_at timestamptz default null,
    p_description text default null,
    p_notes text default null,
    p_dedup_key text default null,
    p_purchase_type text default null,
    p_installment_index integer default null,
    p_installment_count integer default null,
    p_destination_account_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = app_private, extensions
as $$
declare
    v_user_id uuid := auth.uid();
    v_now timestamptz := timezone('utc', now());
    v_transaction_id uuid;
    v_account_type text;
    v_destination_type text;
    v_category_kind text;
    v_origin_occurred_at timestamptz := coalesce(p_origin_occurred_at, p_occurred_at);
    v_occurred_at timestamptz := p_occurred_at;
    v_description text := p_description;
    v_notes text := nullif(trim(coalesce(p_notes, '')), '');
    v_dedup_key text := nullif(trim(coalesce(p_dedup_key, '')), '');
begin
    select a.type into v_account_type
    from app_private.accounts a
    where a.user_id = v_user_id
      and a.id = p_account_id;

    if v_account_type is null then
        return jsonb_build_object('ok', false, 'code', 'invalid_account');
    end if;

    select c.kind into v_category_kind
    from app_private.category_catalog c
    where c.id = p_category_id;

    if v_category_kind is null then
        return jsonb_build_object('ok', false, 'code', 'invalid_category');
    end if;

    if p_subcategory_id is not null and not exists (
        select 1
        from app_private.category_catalog c
        where c.id = p_subcategory_id
          and c.parent_id = p_category_id
          and c.kind = v_category_kind
    ) then
        return jsonb_build_object('ok', false, 'code', 'invalid_subcategory');
    end if;

    if p_amount_cents <= 0 then
        return jsonb_build_object('ok', false, 'code', 'invalid_amount');
    end if;

    if coalesce(length(trim(v_description)), 0) = 0 or v_dedup_key is null then
        return jsonb_build_object('ok', false, 'code', 'unexpected_response');
    end if;

    if v_dedup_key <> app_private.v1_transaction_dedup_key(
        p_account_id,
        p_amount_cents,
        v_description,
        p_purchase_type,
        p_installment_index,
        p_installment_count,
        v_origin_occurred_at
    ) then
        return jsonb_build_object('ok', false, 'code', 'unexpected_response');
    end if;

    if not (
        (p_purchase_type is null and p_installment_index is null and p_installment_count is null)
        or (p_purchase_type = 'cash' and p_installment_index is null and p_installment_count is null)
        or (
            p_purchase_type = 'installment'
            and p_installment_index is not null
            and p_installment_count is not null
            and p_installment_index >= 1
            and p_installment_count >= 2
            and p_installment_index <= p_installment_count
        )
    ) then
        return jsonb_build_object('ok', false, 'code', 'unexpected_response');
    end if;

    if p_destination_account_id is not null then
        if p_destination_account_id = p_account_id or v_category_kind <> 'transfer' then
            return jsonb_build_object('ok', false, 'code', 'invalid_transfer_destination');
        end if;

        select a.type into v_destination_type
        from app_private.accounts a
        where a.user_id = v_user_id
          and a.id = p_destination_account_id;

        if v_destination_type is null then
            return jsonb_build_object('ok', false, 'code', 'invalid_transfer_destination');
        end if;
    end if;

    if v_account_type = 'creditCard' and v_category_kind = 'transfer' then
        return jsonb_build_object('ok', false, 'code', 'invalid_transfer_destination');
    end if;

    if p_purchase_type = 'installment'
       and app_private.v1_is_credit_card_account(v_user_id, p_account_id)
    then
        v_occurred_at := app_private.v1_project_installment_competence(
            v_user_id,
            p_account_id,
            v_origin_occurred_at,
            p_installment_index
        );
    end if;

    begin
        insert into app_private.transactions (
            user_id, account_id, category_id, subcategory_id, amount_cents,
            occurred_at, origin_occurred_at, purchase_type, installment_index, installment_count,
            description, notes, dedup_key, destination_account_id, created_at, updated_at
        ) values (
            v_user_id, p_account_id, p_category_id, p_subcategory_id, p_amount_cents,
            v_occurred_at, v_origin_occurred_at, p_purchase_type, p_installment_index, p_installment_count,
            v_description, v_notes, v_dedup_key, p_destination_account_id, v_now, v_now
        )
        returning id into v_transaction_id;

        if app_private.v1_is_credit_card_account(v_user_id, p_account_id) then
            perform app_private.v1_rebuild_card_statements(v_user_id, p_account_id, v_now);
        end if;

        if p_destination_account_id is not null
           and app_private.v1_is_credit_card_account(v_user_id, p_destination_account_id)
        then
            perform app_private.v1_rebuild_card_statements(v_user_id, p_destination_account_id, v_now);
            perform app_private.v1_assign_card_payment_transaction(
                v_user_id, v_transaction_id, p_destination_account_id, v_now
            );
        end if;
    exception
        when others then
            if sqlerrm in ('unapplied_payment', 'missing_cycle_configuration') then
                return jsonb_build_object('ok', false, 'code', case
                    when sqlerrm = 'missing_cycle_configuration' then 'unexpected_response'
                    else sqlerrm
                end);
            end if;
            raise;
    end;

    return jsonb_build_object('ok', true, 'code', null, 'transaction_id', v_transaction_id);
end;
$$;

drop function if exists api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid);

create or replace function api.v1_update_transaction(
    p_transaction_id uuid,
    p_account_id uuid,
    p_category_id uuid,
    p_subcategory_id uuid,
    p_amount_cents bigint,
    p_occurred_at timestamptz,
    p_origin_occurred_at timestamptz default null,
    p_description text default null,
    p_notes text default null,
    p_dedup_key text default null,
    p_purchase_type text default null,
    p_installment_index integer default null,
    p_installment_count integer default null,
    p_destination_account_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = app_private, extensions
as $$
declare
    v_user_id uuid := auth.uid();
    v_now timestamptz := timezone('utc', now());
    v_current record;
    v_account_type text;
    v_destination_type text;
    v_category_kind text;
    v_origin_occurred_at timestamptz := coalesce(p_origin_occurred_at, p_occurred_at);
    v_occurred_at timestamptz := p_occurred_at;
    v_description text := p_description;
    v_notes text := nullif(trim(coalesce(p_notes, '')), '');
    v_dedup_key text := nullif(trim(coalesce(p_dedup_key, '')), '');
    v_statement_id uuid;
begin
    select
        t.id,
        t.account_id,
        t.category_id,
        t.subcategory_id,
        t.amount_cents,
        t.occurred_at,
        t.origin_occurred_at,
        t.purchase_type,
        t.installment_index,
        t.installment_count,
        t.description,
        t.notes,
        t.dedup_key,
        t.destination_account_id,
        t.statement_id
    into v_current
    from app_private.transactions t
    where t.user_id = v_user_id
      and t.id = p_transaction_id;

    if v_current.id is null then
        return jsonb_build_object('ok', false, 'code', 'transaction_not_found');
    end if;

    select a.type into v_account_type
    from app_private.accounts a
    where a.user_id = v_user_id
      and a.id = p_account_id;

    if v_account_type is null then
        return jsonb_build_object('ok', false, 'code', 'invalid_account');
    end if;

    select c.kind into v_category_kind
    from app_private.category_catalog c
    where c.id = p_category_id;

    if v_category_kind is null then
        return jsonb_build_object('ok', false, 'code', 'invalid_category');
    end if;

    if p_subcategory_id is not null and not exists (
        select 1
        from app_private.category_catalog c
        where c.id = p_subcategory_id
          and c.parent_id = p_category_id
          and c.kind = v_category_kind
    ) then
        return jsonb_build_object('ok', false, 'code', 'invalid_subcategory');
    end if;

    if p_amount_cents <= 0 then
        return jsonb_build_object('ok', false, 'code', 'invalid_amount');
    end if;

    if coalesce(length(trim(v_description)), 0) = 0 or v_dedup_key is null then
        return jsonb_build_object('ok', false, 'code', 'unexpected_response');
    end if;

    if v_dedup_key <> app_private.v1_transaction_dedup_key(
        p_account_id,
        p_amount_cents,
        v_description,
        p_purchase_type,
        p_installment_index,
        p_installment_count,
        v_origin_occurred_at
    ) then
        return jsonb_build_object('ok', false, 'code', 'unexpected_response');
    end if;

    if not (
        (p_purchase_type is null and p_installment_index is null and p_installment_count is null)
        or (p_purchase_type = 'cash' and p_installment_index is null and p_installment_count is null)
        or (
            p_purchase_type = 'installment'
            and p_installment_index is not null
            and p_installment_count is not null
            and p_installment_index >= 1
            and p_installment_count >= 2
            and p_installment_index <= p_installment_count
        )
    ) then
        return jsonb_build_object('ok', false, 'code', 'unexpected_response');
    end if;

    if p_destination_account_id is not null then
        if p_destination_account_id = p_account_id or v_category_kind <> 'transfer' then
            return jsonb_build_object('ok', false, 'code', 'invalid_transfer_destination');
        end if;

        select a.type into v_destination_type
        from app_private.accounts a
        where a.user_id = v_user_id
          and a.id = p_destination_account_id;

        if v_destination_type is null then
            return jsonb_build_object('ok', false, 'code', 'invalid_transfer_destination');
        end if;
    end if;

    if v_account_type = 'creditCard' and v_category_kind = 'transfer' then
        return jsonb_build_object('ok', false, 'code', 'invalid_transfer_destination');
    end if;

    if p_purchase_type = 'installment'
       and v_account_type = 'creditCard'
    then
        v_occurred_at := app_private.v1_project_installment_competence(
            v_user_id,
            p_account_id,
            v_origin_occurred_at,
            p_installment_index
        );
    end if;

    begin
        if v_account_type = 'creditCard' and v_category_kind <> 'transfer' then
            v_statement_id := app_private.v1_find_or_create_statement_for_card_entry(
                v_user_id,
                p_account_id,
                v_occurred_at,
                v_now
            );
        end if;

        if v_current.account_id = p_account_id
           and v_current.category_id = p_category_id
           and v_current.subcategory_id is not distinct from p_subcategory_id
           and v_current.amount_cents = p_amount_cents
           and v_current.occurred_at = v_occurred_at
           and v_current.origin_occurred_at = v_origin_occurred_at
           and v_current.purchase_type is not distinct from p_purchase_type
           and v_current.installment_index is not distinct from p_installment_index
           and v_current.installment_count is not distinct from p_installment_count
           and v_current.description = v_description
           and v_current.notes is not distinct from v_notes
           and v_current.dedup_key = v_dedup_key
           and v_current.destination_account_id is not distinct from p_destination_account_id
           and v_current.statement_id is not distinct from v_statement_id
        then
            return jsonb_build_object('ok', true, 'code', null, 'transaction_id', p_transaction_id);
        end if;

        update app_private.transactions
        set
            account_id = p_account_id,
            category_id = p_category_id,
            subcategory_id = p_subcategory_id,
            amount_cents = p_amount_cents,
            occurred_at = v_occurred_at,
            origin_occurred_at = v_origin_occurred_at,
            purchase_type = p_purchase_type,
            installment_index = p_installment_index,
            installment_count = p_installment_count,
            description = v_description,
            notes = v_notes,
            dedup_key = v_dedup_key,
            destination_account_id = p_destination_account_id,
            statement_id = v_statement_id,
            updated_at = v_now
        where user_id = v_user_id
          and id = p_transaction_id;

        delete from app_private.statement_payments payment
        where payment.user_id = v_user_id
          and payment.transaction_id = p_transaction_id;

        if p_destination_account_id is not null
           and v_destination_type = 'creditCard'
        then
            perform app_private.v1_assign_card_payment_transaction(
                v_user_id, p_transaction_id, p_destination_account_id, v_now
            );
        end if;
    exception
        when others then
            if sqlerrm in ('unapplied_payment', 'missing_cycle_configuration') then
                return jsonb_build_object('ok', false, 'code', case
                    when sqlerrm = 'missing_cycle_configuration' then 'unexpected_response'
                    else sqlerrm
                end);
            end if;
            raise;
    end;

    return jsonb_build_object('ok', true, 'code', null, 'transaction_id', p_transaction_id);
end;
$$;

drop function if exists api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid);

revoke all on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) from public;
revoke all on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) from anon;
revoke all on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) from authenticated;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, text, integer, integer, uuid) from public;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, text, integer, integer, uuid) from anon;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, text, integer, integer, uuid) from authenticated;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, text, integer, integer, uuid) from public;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, text, integer, integer, uuid) from anon;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, text, integer, integer, uuid) from authenticated;

grant execute on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) to authenticated;
grant execute on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, text, integer, integer, uuid) to authenticated;
grant execute on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, text, integer, integer, uuid) to authenticated;

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
        account_id uuid,
        category_slug text not null,
        subcategory_id uuid,
        destination_account_id uuid,
        amount_cents bigint not null,
        occurred_at timestamptz not null,
        origin_occurred_at timestamptz,
        purchase_type text,
        installment_index integer,
        installment_count integer,
        description text not null,
        notes text,
        dedup_key text not null
    ) on commit drop;

    insert into pg_temp.import_transaction_input (
        transaction_id, batch_id, account_id, category_slug, subcategory_id, destination_account_id, amount_cents,
        occurred_at, origin_occurred_at, purchase_type, installment_index, installment_count,
        description, notes, dedup_key
    )
    select
        tx_row.transaction_id, tx_row.batch_id, tx_row.account_id, tx_row.category_slug,
        tx_row.subcategory_id, tx_row.destination_account_id, tx_row.amount_cents,
        tx_row.occurred_at, tx_row.origin_occurred_at, tx_row.purchase_type, tx_row.installment_index,
        tx_row.installment_count, tx_row.description, tx_row.notes, tx_row.dedup_key
    from jsonb_to_recordset(coalesce(p_transactions, '[]'::jsonb)) as tx_row(
        transaction_id uuid,
        batch_id uuid,
        account_id uuid,
        category_slug text,
        subcategory_id uuid,
        destination_account_id uuid,
        amount_cents bigint,
        occurred_at timestamptz,
        origin_occurred_at timestamptz,
        purchase_type text,
        installment_index integer,
        installment_count integer,
        description text,
        notes text,
        dedup_key text
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
        destination_account_id uuid,
        amount_cents bigint not null,
        occurred_at timestamptz not null,
        origin_occurred_at timestamptz not null,
        purchase_type text,
        installment_index integer,
        installment_count integer,
        description text not null,
        notes text,
        dedup_key text not null
    ) on commit drop;

    insert into pg_temp.import_resolved_transaction (
        transaction_id, batch_id, account_id, category_id, subcategory_id, destination_account_id, amount_cents,
        occurred_at, origin_occurred_at, purchase_type, installment_index, installment_count,
        description, notes, dedup_key
    )
    select
        tx.transaction_id, tx.batch_id, coalesce(tx.account_id, batch.account_id), category.id,
        tx.subcategory_id, tx.destination_account_id, tx.amount_cents,
        tx.occurred_at, coalesce(tx.origin_occurred_at, tx.occurred_at),
        nullif(trim(coalesce(tx.purchase_type, '')), ''), tx.installment_index, tx.installment_count,
        tx.description, nullif(trim(coalesce(tx.notes, '')), ''), nullif(trim(coalesce(tx.dedup_key, '')), '')
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
        left join app_private.accounts account
            on account.user_id = p_user_id
           and account.id = tx.account_id
        where account.id is null
    ) then
        return 'invalid_account';
    end if;

    if exists (
        select 1
        from pg_temp.import_resolved_transaction tx
        left join app_private.accounts destination
            on destination.user_id = p_user_id
           and destination.id = tx.destination_account_id
        where tx.destination_account_id is not null
          and destination.id is null
    ) then
        return 'invalid_account';
    end if;

    if exists (
        select 1
        from pg_temp.import_resolved_transaction tx
        join app_private.category_catalog category on category.id = tx.category_id
        where (
            category.kind = 'transfer'
            and (
                tx.subcategory_id is not null
                or tx.destination_account_id is null
                or tx.destination_account_id = tx.account_id
            )
        )
        or (
            category.kind <> 'transfer'
            and tx.destination_account_id is not null
        )
    ) then
        return 'unexpected_response';
    end if;

    if exists (
        select 1
        from pg_temp.import_resolved_transaction tx
        where tx.amount_cents <= 0
           or length(trim(tx.description)) = 0
           or length(tx.dedup_key) = 0
           or (tx.purchase_type is not null and tx.purchase_type not in ('cash', 'installment'))
    ) then
        return 'unexpected_response';
    end if;

    if exists (
        select 1
        from pg_temp.import_resolved_transaction tx
        where tx.dedup_key <> app_private.v1_transaction_dedup_key(
            tx.account_id,
            tx.amount_cents,
            tx.description,
            tx.purchase_type,
            tx.installment_index,
            tx.installment_count,
            tx.origin_occurred_at
        )
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
        destination_account_id uuid,
        amount_cents bigint not null,
        occurred_at timestamptz not null,
        origin_occurred_at timestamptz not null,
        purchase_type text,
        installment_index integer,
        installment_count integer,
        description text not null,
        notes text,
        dedup_key text not null
    ) on commit drop;

    insert into pg_temp.import_expanded_transaction (
        transaction_id, batch_id, account_id, category_id, subcategory_id, destination_account_id, amount_cents,
        occurred_at, origin_occurred_at, purchase_type, installment_index, installment_count,
        description, notes, dedup_key
    )
    select
        tx.transaction_id, tx.batch_id, tx.account_id, tx.category_id, tx.subcategory_id,
        tx.destination_account_id, tx.amount_cents,
        case
            when tx.purchase_type = 'installment'
                 and app_private.v1_is_credit_card_account(p_user_id, tx.account_id)
            then app_private.v1_project_installment_competence(
                p_user_id, tx.account_id, tx.origin_occurred_at, tx.installment_index
            )
            else tx.occurred_at
        end,
        tx.origin_occurred_at,
        tx.purchase_type,
        tx.installment_index,
        tx.installment_count,
        tx.description,
        case
            when tx.purchase_type = 'installment'
                 and app_private.v1_is_credit_card_account(p_user_id, tx.account_id)
            then app_private.v1_rebuild_inter_import_notes(
                tx.purchase_type, tx.installment_index, tx.installment_count, tx.notes
            )
            else tx.notes
        end,
        tx.dedup_key
    from pg_temp.import_resolved_transaction tx;

    create temporary table pg_temp.import_duplicate_row (
        batch_id uuid not null,
        dedup_key text not null,
        description text not null,
        occurred_at timestamptz not null
    ) on commit drop;

    insert into pg_temp.import_duplicate_row (
        batch_id, dedup_key, description, occurred_at
    )
    select tx.batch_id, tx.dedup_key, tx.description, tx.occurred_at
    from (
        select
            resolved.*,
            row_number() over (
                partition by resolved.account_id, resolved.dedup_key
                order by resolved.occurred_at asc, resolved.transaction_id asc
            ) as duplicate_rank
        from pg_temp.import_expanded_transaction resolved
    ) tx
    where tx.duplicate_rank > 1;

    insert into pg_temp.import_duplicate_row (
        batch_id, dedup_key, description, occurred_at
    )
    select tx.batch_id, tx.dedup_key, tx.description, tx.occurred_at
    from pg_temp.import_expanded_transaction tx
    where exists (
        select 1
        from app_private.transactions existing
        where existing.user_id = p_user_id
          and existing.account_id = tx.account_id
          and existing.dedup_key = tx.dedup_key
    );

    create temporary table pg_temp.import_insertable_transaction (
        transaction_id uuid primary key,
        batch_id uuid not null,
        account_id uuid not null,
        category_id uuid not null,
        subcategory_id uuid,
        destination_account_id uuid,
        amount_cents bigint not null,
        occurred_at timestamptz not null,
        origin_occurred_at timestamptz not null,
        purchase_type text,
        installment_index integer,
        installment_count integer,
        description text not null,
        notes text,
        dedup_key text not null
    ) on commit drop;

    insert into pg_temp.import_insertable_transaction (
        transaction_id, batch_id, account_id, category_id, subcategory_id, destination_account_id, amount_cents,
        occurred_at, origin_occurred_at, purchase_type, installment_index, installment_count,
        description, notes, dedup_key
    )
    select
        tx.transaction_id, tx.batch_id, tx.account_id, tx.category_id, tx.subcategory_id,
        tx.destination_account_id, tx.amount_cents,
        tx.occurred_at, tx.origin_occurred_at, tx.purchase_type, tx.installment_index, tx.installment_count,
        tx.description, tx.notes, tx.dedup_key
    from pg_temp.import_expanded_transaction tx
    where not exists (
        select 1
        from pg_temp.import_duplicate_row duplicate_row
        where duplicate_row.batch_id = tx.batch_id
          and duplicate_row.dedup_key = tx.dedup_key
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
        description, notes, import_batch_id, dedup_key, destination_account_id, created_at, updated_at
    )
    select
        tx.transaction_id, p_user_id, tx.account_id, tx.category_id, tx.subcategory_id, tx.amount_cents,
        tx.occurred_at, tx.origin_occurred_at, tx.purchase_type, tx.installment_index, tx.installment_count,
        tx.description, tx.notes, tx.batch_id, tx.dedup_key, tx.destination_account_id, p_now, p_now
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
                        'dedup_key', duplicate_row.dedup_key,
                        'description', duplicate_row.description,
                        'occurred_at', duplicate_row.occurred_at
                    )
                    order by duplicate_row.occurred_at desc, duplicate_row.dedup_key asc
                )
                from (
                    select distinct row.batch_id, row.dedup_key, row.description, row.occurred_at
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
