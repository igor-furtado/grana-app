-- Ticket #31 rollback manual:
-- 1. restaurar backup das linhas removidas de app_private.transactions com refund_of_transaction_id preenchido;
-- 2. readicionar app_private.transactions.refund_of_transaction_id e seu foreign key composto;
-- 3. restaurar as assinaturas antigas de api.v1_create_transaction/api.v1_update_transaction;
-- 4. restaurar os contratos antigos de listagem/importacao/dashboard/faturas se necessario.

create temporary table pg_temp.legacy_refund_cleanup_account (
    user_id uuid not null,
    account_id uuid not null,
    primary key (user_id, account_id)
) on commit drop;

insert into pg_temp.legacy_refund_cleanup_account (user_id, account_id)
select distinct refund.user_id, refund.account_id
from app_private.transactions refund
where refund.refund_of_transaction_id is not null
union
select distinct purchase.user_id, purchase.account_id
from app_private.transactions refund
join app_private.transactions purchase
    on purchase.user_id = refund.user_id
   and purchase.id = refund.refund_of_transaction_id
where refund.refund_of_transaction_id is not null;

delete from app_private.transactions
where refund_of_transaction_id is not null;

update app_private.import_batches batch
set
    row_count = counts.row_count,
    updated_at = timezone('utc', now())
from (
    select
        tx.user_id,
        tx.import_batch_id as batch_id,
        count(*)::integer as row_count
    from app_private.transactions tx
    where tx.import_batch_id is not null
    group by tx.user_id, tx.import_batch_id
) counts
where batch.user_id = counts.user_id
  and batch.id = counts.batch_id;

delete from app_private.import_batches batch
where not exists (
    select 1
    from app_private.transactions tx
    where tx.user_id = batch.user_id
      and tx.import_batch_id = batch.id
);

alter table app_private.transactions
drop column if exists refund_of_transaction_id;

create or replace function app_private.v1_rebuild_card_statements(
    p_user_id uuid,
    p_account_id uuid,
    p_reference_date timestamptz default timezone('utc', now())
)
returns void
language plpgsql
security definer
set search_path = app_private, extensions
as $$
declare
    v_now timestamptz := timezone('utc', now());
    v_entry record;
    v_statement_id uuid;
begin
    if not app_private.v1_is_credit_card_account(p_user_id, p_account_id) then
        return;
    end if;

    drop table if exists pg_temp.statement_tx_map;
    create temporary table pg_temp.statement_tx_map (
        transaction_id uuid primary key,
        statement_id uuid not null
    ) on commit drop;

    for v_entry in
        select
            card_entry.id,
            card_entry.occurred_at
        from app_private.transactions card_entry
        join app_private.category_catalog category
            on category.id = card_entry.category_id
        where card_entry.user_id = p_user_id
          and card_entry.account_id = p_account_id
          and category.kind <> 'transfer'
        order by card_entry.occurred_at asc, card_entry.id asc
    loop
        v_statement_id := app_private.v1_find_or_create_statement_for_card_entry(
            p_user_id,
            p_account_id,
            v_entry.occurred_at,
            p_reference_date
        );

        insert into pg_temp.statement_tx_map (
            transaction_id,
            statement_id
        ) values (
            v_entry.id,
            v_statement_id
        )
        on conflict (transaction_id) do update
        set statement_id = excluded.statement_id;
    end loop;

    update app_private.transactions txn
    set
        statement_id = tx_map.statement_id,
        updated_at = case
            when txn.statement_id is distinct from tx_map.statement_id then v_now
            else txn.updated_at
        end
    from pg_temp.statement_tx_map tx_map
    where txn.user_id = p_user_id
      and txn.id = tx_map.transaction_id;

    update app_private.transactions txn
    set
        statement_id = null,
        updated_at = case
            when txn.statement_id is not null then v_now
            else txn.updated_at
        end
    where txn.user_id = p_user_id
      and txn.account_id = p_account_id
      and not exists (
          select 1
          from pg_temp.statement_tx_map tx_map
          where tx_map.transaction_id = txn.id
      );

    delete from app_private.statement_credit_applications credit
    using app_private.statements statement
    where credit.user_id = p_user_id
      and statement.user_id = p_user_id
      and statement.account_id = p_account_id
      and (
          credit.source_statement_id = statement.id
          or credit.destination_statement_id = statement.id
      );
end;
$$;

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
    description text,
    notes text,
    import_batch_id uuid,
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
        t.description,
        t.notes,
        t.import_batch_id,
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

create or replace function api.v1_list_statements()
returns table (
    id uuid,
    account_id uuid,
    closing_date timestamptz,
    due_date timestamptz,
    net_amount_cents bigint,
    credit_received_cents bigint,
    payment_applied_cents bigint,
    settled_at timestamptz,
    created_at timestamptz,
    updated_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
    with transaction_totals as (
        select
            txn.statement_id,
            coalesce(sum(case
                when category.kind = 'expense' then txn.amount_cents
                when category.kind = 'income' then -txn.amount_cents
                else 0
            end), 0) as net_amount_cents
        from app_private.transactions txn
        join app_private.category_catalog category
            on category.id = txn.category_id
        where txn.user_id = auth.uid()
          and txn.statement_id is not null
          and category.kind <> 'transfer'
        group by txn.statement_id
    ),
    payment_totals as (
        select
            payment.statement_id,
            coalesce(sum(payment.applied_amount_cents), 0) as payment_applied_cents,
            max(payment.created_at) as last_payment_at
        from app_private.statement_payments payment
        where payment.user_id = auth.uid()
        group by payment.statement_id
    )
    select
        statement.id,
        statement.account_id,
        statement.closing_date,
        statement.due_date,
        coalesce(transaction_totals.net_amount_cents, 0) as net_amount_cents,
        0::bigint as credit_received_cents,
        coalesce(payment_totals.payment_applied_cents, 0) as payment_applied_cents,
        case
            when greatest(coalesce(transaction_totals.net_amount_cents, 0), 0)
                 > coalesce(payment_totals.payment_applied_cents, 0)
            then null
            when greatest(coalesce(transaction_totals.net_amount_cents, 0), 0) = 0
            then null
            else greatest(
                statement.closing_date,
                coalesce(payment_totals.last_payment_at, statement.updated_at)
            )
        end as settled_at,
        statement.created_at,
        statement.updated_at
    from app_private.statements statement
    left join transaction_totals
        on transaction_totals.statement_id = statement.id
    left join payment_totals
        on payment_totals.statement_id = statement.id
    where statement.user_id = auth.uid()
    order by statement.due_date desc, statement.closing_date desc, statement.created_at desc, statement.id desc
$$;

create or replace function app_private.v1_assign_card_payment_transaction(
    p_user_id uuid,
    p_transaction_id uuid,
    p_account_id uuid,
    p_reference_date timestamptz default timezone('utc', now())
)
returns void
language plpgsql
security definer
set search_path = app_private, extensions
as $$
declare
    v_payment record;
    v_statement record;
    v_remaining bigint;
    v_apply bigint;
begin
    if not app_private.v1_is_credit_card_account(p_user_id, p_account_id) then
        return;
    end if;

    select
        txn.id,
        txn.amount_cents,
        txn.occurred_at,
        category.kind
    into v_payment
    from app_private.transactions txn
    join app_private.category_catalog category
        on category.id = txn.category_id
    where txn.user_id = p_user_id
      and txn.id = p_transaction_id;

    if v_payment.id is null or v_payment.kind <> 'transfer' then
        return;
    end if;

    delete from app_private.statement_payments payment
    where payment.user_id = p_user_id
      and payment.transaction_id = p_transaction_id;

    v_remaining := v_payment.amount_cents;

    for v_statement in
        with transaction_totals as (
            select
                txn.statement_id,
                coalesce(sum(case
                    when category.kind = 'expense' then txn.amount_cents
                    when category.kind = 'income' then -txn.amount_cents
                    else 0
                end), 0) as net_amount_cents,
                min(txn.occurred_at) as first_entry_at
            from app_private.transactions txn
            join app_private.category_catalog category
                on category.id = txn.category_id
            where txn.user_id = p_user_id
              and txn.statement_id is not null
              and category.kind <> 'transfer'
            group by txn.statement_id
        ),
        payment_totals as (
            select
                payment.statement_id,
                coalesce(sum(payment.applied_amount_cents), 0) as payment_applied_cents
            from app_private.statement_payments payment
            where payment.user_id = p_user_id
            group by payment.statement_id
        )
        select
            statement.id,
            coalesce(transaction_totals.net_amount_cents, 0) as net_amount_cents,
            coalesce(payment_totals.payment_applied_cents, 0) as payment_applied_cents,
            transaction_totals.first_entry_at
        from app_private.statements statement
        left join transaction_totals
            on transaction_totals.statement_id = statement.id
        left join payment_totals
            on payment_totals.statement_id = statement.id
        where statement.user_id = p_user_id
          and statement.account_id = p_account_id
          and transaction_totals.first_entry_at <= v_payment.occurred_at
        order by statement.due_date asc, statement.closing_date asc, statement.created_at asc, statement.id asc
    loop
        exit when v_remaining <= 0;

        v_apply := least(
            greatest(0, v_statement.net_amount_cents - v_statement.payment_applied_cents),
            v_remaining
        );

        if v_apply <= 0 then
            continue;
        end if;

        insert into app_private.statement_payments (
            user_id,
            statement_id,
            transaction_id,
            applied_amount_cents
        ) values (
            p_user_id,
            v_statement.id,
            p_transaction_id,
            v_apply
        );

        v_remaining := v_remaining - v_apply;
    end loop;

    if v_remaining <> 0 then
        raise exception using message = 'unapplied_payment';
    end if;
end;
$$;

drop function if exists api.v1_list_statement_transactions(uuid);

create function api.v1_list_statement_transactions(
    p_statement_id uuid
)
returns table (
    id uuid,
    account_id uuid,
    category_id uuid,
    subcategory_id uuid,
    amount_cents bigint,
    occurred_at timestamptz,
    description text,
    notes text,
    import_batch_id uuid,
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
        txn.id,
        txn.account_id,
        txn.category_id,
        txn.subcategory_id,
        txn.amount_cents,
        txn.occurred_at,
        txn.description,
        txn.notes,
        txn.import_batch_id,
        txn.external_id,
        txn.destination_account_id,
        txn.statement_id,
        txn.created_at,
        txn.updated_at
    from app_private.transactions txn
    where txn.user_id = auth.uid()
      and txn.statement_id = p_statement_id
    order by txn.occurred_at desc, txn.created_at desc, txn.id desc
$$;

create or replace function api.v1_update_statement_dates(
    p_statement_id uuid,
    p_closing_date date,
    p_due_date date
)
returns jsonb
language plpgsql
security definer
set search_path = api, app_private, extensions
as $$
declare
    v_user_id uuid := auth.uid();
    v_now timestamptz := timezone('utc', now());
    v_statement record;
    v_closing_day date := p_closing_date;
    v_due_day date := p_due_date;
    v_previous_closing date;
    v_next_closing date;
    v_moved_count integer := 0;
    v_entered_count integer := 0;
    v_exited_count integer := 0;
    v_affected_statement_count integer := 0;
    v_payment_difference_statement_count integer := 0;
begin
    if v_user_id is null then
        return jsonb_build_object('ok', false, 'code', 'authentication_required');
    end if;

    select
        statement.id,
        statement.account_id,
        statement.closing_date,
        statement.due_date
    into v_statement
    from app_private.statements statement
    where statement.user_id = v_user_id
      and statement.id = p_statement_id;

    if v_statement.id is null then
        return jsonb_build_object('ok', false, 'code', 'statement_not_found');
    end if;

    if not app_private.v1_is_credit_card_account(v_user_id, v_statement.account_id) then
        return jsonb_build_object('ok', false, 'code', 'invalid_account');
    end if;

    if v_due_day <= v_closing_day then
        return jsonb_build_object('ok', false, 'code', 'invalid_statement_dates');
    end if;

    select max((statement.closing_date at time zone 'UTC')::date)
    into v_previous_closing
    from app_private.statements statement
    where statement.user_id = v_user_id
      and statement.account_id = v_statement.account_id
      and statement.id <> p_statement_id
      and statement.closing_date < v_statement.closing_date;

    select min((statement.closing_date at time zone 'UTC')::date)
    into v_next_closing
    from app_private.statements statement
    where statement.user_id = v_user_id
      and statement.account_id = v_statement.account_id
      and statement.id <> p_statement_id
      and statement.closing_date > v_statement.closing_date;

    if v_previous_closing is not null and v_closing_day <= v_previous_closing then
        return jsonb_build_object('ok', false, 'code', 'statement_closing_before_previous');
    end if;

    if v_next_closing is not null and v_closing_day >= v_next_closing then
        return jsonb_build_object('ok', false, 'code', 'statement_closing_after_next');
    end if;

    if exists (
        select 1
        from app_private.statements statement
        where statement.user_id = v_user_id
          and statement.account_id = v_statement.account_id
          and statement.id <> p_statement_id
          and (statement.closing_date at time zone 'UTC')::date = v_closing_day
    ) then
        return jsonb_build_object('ok', false, 'code', 'statement_closing_conflict');
    end if;

    create temporary table pg_temp.statement_link_before (
        transaction_id uuid primary key,
        statement_id uuid
    ) on commit drop;

    insert into pg_temp.statement_link_before (
        transaction_id,
        statement_id
    )
    select
        txn.id,
        txn.statement_id
    from app_private.transactions txn
    join app_private.category_catalog category
        on category.id = txn.category_id
    where txn.user_id = v_user_id
      and txn.account_id = v_statement.account_id
      and category.kind <> 'transfer';

    update app_private.statements
    set
        closing_date = app_private.v1_utc_midnight(v_closing_day),
        due_date = app_private.v1_utc_midnight(v_due_day),
        updated_at = v_now
    where user_id = v_user_id
      and id = p_statement_id;

    perform app_private.v1_rebuild_card_statements(v_user_id, v_statement.account_id, v_now);

    create temporary table pg_temp.statement_date_edit_affected_statements (
        statement_id uuid primary key
    ) on commit drop;

    insert into pg_temp.statement_date_edit_affected_statements (statement_id)
    values (p_statement_id);

    with changed as (
        select
            before_map.transaction_id,
            before_map.statement_id as before_statement_id,
            txn.statement_id as after_statement_id
        from pg_temp.statement_link_before before_map
        join app_private.transactions txn
            on txn.user_id = v_user_id
           and txn.id = before_map.transaction_id
        where before_map.statement_id is distinct from txn.statement_id
    ),
    affected as (
        select unnest(array_remove(array[before_statement_id, after_statement_id], null)) as statement_id
        from changed
    )
    insert into pg_temp.statement_date_edit_affected_statements (statement_id)
    select distinct statement_id
    from affected
    on conflict (statement_id) do nothing;

    with changed as (
        select
            before_map.transaction_id,
            before_map.statement_id as before_statement_id,
            txn.statement_id as after_statement_id
        from pg_temp.statement_link_before before_map
        join app_private.transactions txn
            on txn.user_id = v_user_id
           and txn.id = before_map.transaction_id
        where before_map.statement_id is distinct from txn.statement_id
    )
    select
        count(distinct transaction_id)::integer,
        count(distinct transaction_id) filter (
            where before_statement_id is distinct from p_statement_id
              and after_statement_id = p_statement_id
        )::integer,
        count(distinct transaction_id) filter (
            where before_statement_id = p_statement_id
              and after_statement_id is distinct from p_statement_id
        )::integer
    into
        v_moved_count,
        v_entered_count,
        v_exited_count
    from changed;

    select count(*)::integer
    into v_affected_statement_count
    from pg_temp.statement_date_edit_affected_statements;

    with transaction_totals as (
        select
            statement.id as statement_id,
            coalesce(sum(case
                when category.kind = 'expense' then txn.amount_cents
                when category.kind = 'income' then -txn.amount_cents
                else 0
            end), 0) as net_amount_cents
        from app_private.statements statement
        left join app_private.transactions txn
            on txn.user_id = statement.user_id
           and txn.statement_id = statement.id
        left join app_private.category_catalog category
            on category.id = txn.category_id
        where statement.user_id = v_user_id
          and statement.account_id = v_statement.account_id
        group by statement.id
    ),
    payment_totals as (
        select
            statement.id as statement_id,
            coalesce(sum(payment.applied_amount_cents), 0) as payment_applied_cents
        from app_private.statements statement
        left join app_private.statement_payments payment
            on payment.user_id = statement.user_id
           and payment.statement_id = statement.id
        where statement.user_id = v_user_id
          and statement.account_id = v_statement.account_id
        group by statement.id
    )
    select count(*)::integer
    into v_payment_difference_statement_count
    from transaction_totals
    join payment_totals
        on payment_totals.statement_id = transaction_totals.statement_id
    join pg_temp.statement_date_edit_affected_statements affected_statement
        on affected_statement.statement_id = transaction_totals.statement_id
    where (
        greatest(transaction_totals.net_amount_cents, 0)
        <> payment_totals.payment_applied_cents
    )
      and (
          greatest(transaction_totals.net_amount_cents, 0) > 0
          or payment_totals.payment_applied_cents > 0
      );

    return jsonb_build_object(
        'ok', true,
        'code', null,
        'statement_id', p_statement_id,
        'moved_transaction_count', coalesce(v_moved_count, 0),
        'entered_transaction_count', coalesce(v_entered_count, 0),
        'exited_transaction_count', coalesce(v_exited_count, 0),
        'affected_statement_count', coalesce(v_affected_statement_count, 0),
        'payment_difference_statement_count', coalesce(v_payment_difference_statement_count, 0)
    );
end;
$$;

drop function if exists api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid);

create function api.v1_create_transaction(
    p_account_id uuid,
    p_category_id uuid,
    p_subcategory_id uuid,
    p_amount_cents bigint,
    p_occurred_at timestamptz,
    p_description text,
    p_notes text,
    p_destination_account_id uuid
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
begin
    select a.type
    into v_account_type
    from app_private.accounts a
    where a.user_id = v_user_id
      and a.id = p_account_id;

    if v_account_type is null then
        return jsonb_build_object('ok', false, 'code', 'invalid_account');
    end if;

    select c.kind
    into v_category_kind
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

    if coalesce(length(trim(p_description)), 0) = 0 then
        return jsonb_build_object('ok', false, 'code', 'unexpected_response');
    end if;

    if p_destination_account_id is not null then
        if p_destination_account_id = p_account_id or v_category_kind <> 'transfer' then
            return jsonb_build_object('ok', false, 'code', 'invalid_transfer_destination');
        end if;

        select a.type
        into v_destination_type
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

    begin
        insert into app_private.transactions (
            user_id,
            account_id,
            category_id,
            subcategory_id,
            amount_cents,
            occurred_at,
            description,
            notes,
            destination_account_id,
            created_at,
            updated_at
        ) values (
            v_user_id,
            p_account_id,
            p_category_id,
            p_subcategory_id,
            p_amount_cents,
            p_occurred_at,
            trim(p_description),
            nullif(trim(coalesce(p_notes, '')), ''),
            p_destination_account_id,
            v_now,
            v_now
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
                v_user_id,
                v_transaction_id,
                p_destination_account_id,
                v_now
            );
        end if;
    exception
        when others then
            if sqlerrm in (
                'unapplied_payment',
                'missing_cycle_configuration'
            ) then
                return jsonb_build_object('ok', false, 'code', case
                    when sqlerrm = 'missing_cycle_configuration' then 'unexpected_response'
                    else sqlerrm
                end);
            end if;
            raise;
    end;

    return jsonb_build_object(
        'ok', true,
        'code', null,
        'transaction_id', v_transaction_id
    );
end;
$$;

drop function if exists api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid);

create function api.v1_update_transaction(
    p_transaction_id uuid,
    p_account_id uuid,
    p_category_id uuid,
    p_subcategory_id uuid,
    p_amount_cents bigint,
    p_occurred_at timestamptz,
    p_description text,
    p_notes text,
    p_destination_account_id uuid
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
begin
    select
        t.id,
        t.account_id,
        t.destination_account_id
    into v_current
    from app_private.transactions t
    where t.user_id = v_user_id
      and t.id = p_transaction_id;

    if v_current.id is null then
        return jsonb_build_object('ok', false, 'code', 'transaction_not_found');
    end if;

    select a.type
    into v_account_type
    from app_private.accounts a
    where a.user_id = v_user_id
      and a.id = p_account_id;

    if v_account_type is null then
        return jsonb_build_object('ok', false, 'code', 'invalid_account');
    end if;

    select c.kind
    into v_category_kind
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

    if coalesce(length(trim(p_description)), 0) = 0 then
        return jsonb_build_object('ok', false, 'code', 'unexpected_response');
    end if;

    if p_destination_account_id is not null then
        if p_destination_account_id = p_account_id or v_category_kind <> 'transfer' then
            return jsonb_build_object('ok', false, 'code', 'invalid_transfer_destination');
        end if;

        select a.type
        into v_destination_type
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

    begin
        update app_private.transactions
        set
            account_id = p_account_id,
            category_id = p_category_id,
            subcategory_id = p_subcategory_id,
            amount_cents = p_amount_cents,
            occurred_at = p_occurred_at,
            description = trim(p_description),
            notes = nullif(trim(coalesce(p_notes, '')), ''),
            destination_account_id = p_destination_account_id,
            updated_at = v_now
        where user_id = v_user_id
          and id = p_transaction_id;

        delete from app_private.statement_payments payment
        where payment.user_id = v_user_id
          and payment.transaction_id = p_transaction_id;

        if app_private.v1_is_credit_card_account(v_user_id, v_current.account_id) then
            perform app_private.v1_rebuild_card_statements(v_user_id, v_current.account_id, v_now);
        end if;

        if v_current.destination_account_id is not null
           and app_private.v1_is_credit_card_account(v_user_id, v_current.destination_account_id)
        then
            perform app_private.v1_rebuild_card_statements(v_user_id, v_current.destination_account_id, v_now);
        end if;

        if app_private.v1_is_credit_card_account(v_user_id, p_account_id)
           and p_account_id <> v_current.account_id
        then
            perform app_private.v1_rebuild_card_statements(v_user_id, p_account_id, v_now);
        end if;

        if p_destination_account_id is not null
           and p_destination_account_id <> v_current.destination_account_id
           and app_private.v1_is_credit_card_account(v_user_id, p_destination_account_id)
        then
            perform app_private.v1_rebuild_card_statements(v_user_id, p_destination_account_id, v_now);
        end if;

        if p_destination_account_id is not null
           and app_private.v1_is_credit_card_account(v_user_id, p_destination_account_id)
        then
            perform app_private.v1_assign_card_payment_transaction(
                v_user_id,
                p_transaction_id,
                p_destination_account_id,
                v_now
            );
        end if;
    exception
        when others then
            if sqlerrm in (
                'unapplied_payment',
                'missing_cycle_configuration'
            ) then
                return jsonb_build_object('ok', false, 'code', case
                    when sqlerrm = 'missing_cycle_configuration' then 'unexpected_response'
                    else sqlerrm
                end);
            end if;
            raise;
    end;

    return jsonb_build_object(
        'ok', true,
        'code', null,
        'transaction_id', p_transaction_id
    );
end;
$$;

create or replace function api.v1_delete_transaction(
    p_transaction_id uuid
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
begin
    select
        t.id,
        t.account_id,
        t.destination_account_id,
        destination.type as destination_account_type,
        t.statement_id
    into v_current
    from app_private.transactions t
    left join app_private.accounts destination
        on destination.user_id = v_user_id
       and destination.id = t.destination_account_id
    where t.user_id = v_user_id
      and t.id = p_transaction_id;

    if v_current.id is null then
        return jsonb_build_object('ok', false, 'code', 'transaction_not_found');
    end if;

    if v_current.statement_id is not null
       or v_current.destination_account_type = 'creditCard'
    then
        return jsonb_build_object('ok', false, 'code', 'credit_card_transactions_not_supported');
    end if;

    delete from app_private.transactions
    where user_id = v_user_id
      and id = p_transaction_id;

    if app_private.v1_is_credit_card_account(v_user_id, v_current.account_id) then
        perform app_private.v1_rebuild_card_statements(v_user_id, v_current.account_id, v_now);
    end if;

    return jsonb_build_object(
        'ok', true,
        'code', null,
        'transaction_id', p_transaction_id
    );
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
    v_account_id uuid;
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

    create temporary table pg_temp.import_batch_input (
        batch_id uuid primary key,
        source_filename text not null,
        account_id uuid not null,
        imported_at timestamptz not null,
        import_format text not null
    ) on commit drop;

    insert into pg_temp.import_batch_input (
        batch_id,
        source_filename,
        account_id,
        imported_at,
        import_format
    )
    select
        batch_row.batch_id,
        batch_row.source_filename,
        batch_row.account_id,
        batch_row.imported_at,
        batch_row.import_format
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
        description text not null,
        notes text,
        external_id text
    ) on commit drop;

    insert into pg_temp.import_transaction_input (
        transaction_id,
        batch_id,
        category_slug,
        subcategory_id,
        amount_cents,
        occurred_at,
        description,
        notes,
        external_id
    )
    select
        tx_row.transaction_id,
        tx_row.batch_id,
        tx_row.category_slug,
        tx_row.subcategory_id,
        tx_row.amount_cents,
        tx_row.occurred_at,
        tx_row.description,
        tx_row.notes,
        tx_row.external_id
    from jsonb_to_recordset(coalesce(p_transactions, '[]'::jsonb)) as tx_row(
        transaction_id uuid,
        batch_id uuid,
        category_slug text,
        subcategory_id uuid,
        amount_cents bigint,
        occurred_at timestamptz,
        description text,
        notes text,
        external_id text
    );

    if exists (
        select 1
        from pg_temp.import_transaction_input tx
        left join pg_temp.import_batch_input batch
            on batch.batch_id = tx.batch_id
        where batch.batch_id is null
    ) then
        return jsonb_build_object('ok', false, 'code', 'unexpected_response');
    end if;

    if exists (
        select 1
        from pg_temp.import_transaction_input tx
        join pg_temp.import_batch_input batch
            on batch.batch_id = tx.batch_id
        left join app_private.accounts account
            on account.user_id = v_user_id
           and account.id = batch.account_id
        where account.id is null
    ) then
        return jsonb_build_object('ok', false, 'code', 'invalid_account');
    end if;

    if exists (
        select 1
        from pg_temp.import_batch_input batch
        join app_private.accounts account
            on account.user_id = v_user_id
           and account.id = batch.account_id
        left join app_private.supported_institutions_catalog institution
            on institution.id = account.institution_id
        where institution.id is null
           or not (batch.import_format = any(institution.supported_import_formats))
    ) then
        return jsonb_build_object('ok', false, 'code', 'unsupported_import_format');
    end if;

    create temporary table pg_temp.import_resolved_transaction (
        transaction_id uuid primary key,
        batch_id uuid not null,
        account_id uuid not null,
        category_id uuid not null,
        subcategory_id uuid,
        amount_cents bigint not null,
        occurred_at timestamptz not null,
        description text not null,
        notes text,
        external_id text
    ) on commit drop;

    insert into pg_temp.import_resolved_transaction (
        transaction_id,
        batch_id,
        account_id,
        category_id,
        subcategory_id,
        amount_cents,
        occurred_at,
        description,
        notes,
        external_id
    )
    select
        tx.transaction_id,
        tx.batch_id,
        batch.account_id,
        category.id,
        tx.subcategory_id,
        tx.amount_cents,
        tx.occurred_at,
        trim(tx.description),
        nullif(trim(coalesce(tx.notes, '')), ''),
        nullif(trim(coalesce(tx.external_id, '')), '')
    from pg_temp.import_transaction_input tx
    join pg_temp.import_batch_input batch
        on batch.batch_id = tx.batch_id
    join app_private.category_catalog category
        on category.parent_id is null
       and category.slug = tx.category_slug;

    if (select count(*) from pg_temp.import_resolved_transaction)
       <> (select count(*) from pg_temp.import_transaction_input)
    then
        return jsonb_build_object('ok', false, 'code', 'invalid_category');
    end if;

    if exists (
        select 1
        from pg_temp.import_resolved_transaction tx
        where tx.amount_cents <= 0
           or length(trim(tx.description)) = 0
    ) then
        return jsonb_build_object('ok', false, 'code', 'unexpected_response');
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
        return jsonb_build_object('ok', false, 'code', 'invalid_subcategory');
    end if;

    create temporary table pg_temp.import_duplicate_row (
        batch_id uuid not null,
        external_id text not null,
        description text not null,
        occurred_at timestamptz not null
    ) on commit drop;

    insert into pg_temp.import_duplicate_row (
        batch_id,
        external_id,
        description,
        occurred_at
    )
    select
        tx.batch_id,
        tx.external_id,
        tx.description,
        tx.occurred_at
    from (
        select
            resolved.*,
            row_number() over (
                partition by resolved.account_id, resolved.external_id
                order by resolved.occurred_at asc, resolved.transaction_id asc
            ) as duplicate_rank
        from pg_temp.import_resolved_transaction resolved
        where resolved.external_id is not null
    ) tx
    where tx.duplicate_rank > 1;

    insert into pg_temp.import_duplicate_row (
        batch_id,
        external_id,
        description,
        occurred_at
    )
    select
        tx.batch_id,
        tx.external_id,
        tx.description,
        tx.occurred_at
    from pg_temp.import_resolved_transaction tx
    where tx.external_id is not null
      and exists (
          select 1
          from app_private.transactions existing
          where existing.user_id = v_user_id
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
        description text not null,
        notes text,
        external_id text
    ) on commit drop;

    insert into pg_temp.import_insertable_transaction (
        transaction_id,
        batch_id,
        account_id,
        category_id,
        subcategory_id,
        amount_cents,
        occurred_at,
        description,
        notes,
        external_id
    )
    select
        tx.transaction_id,
        tx.batch_id,
        tx.account_id,
        tx.category_id,
        tx.subcategory_id,
        tx.amount_cents,
        tx.occurred_at,
        tx.description,
        tx.notes,
        tx.external_id
    from pg_temp.import_resolved_transaction tx
    where not exists (
        select 1
        from pg_temp.import_duplicate_row duplicate_row
        where duplicate_row.batch_id = tx.batch_id
          and duplicate_row.external_id = tx.external_id
          and duplicate_row.occurred_at = tx.occurred_at
          and duplicate_row.description = tx.description
    );

    insert into app_private.import_batches (
        id,
        user_id,
        source_filename,
        account_id,
        row_count,
        imported_at,
        created_at,
        updated_at
    )
    select
        batch.batch_id,
        v_user_id,
        batch.source_filename,
        batch.account_id,
        count(tx.transaction_id)::integer,
        batch.imported_at,
        v_now,
        v_now
    from pg_temp.import_batch_input batch
    join pg_temp.import_insertable_transaction tx
        on tx.batch_id = batch.batch_id
    group by
        batch.batch_id,
        batch.source_filename,
        batch.account_id,
        batch.imported_at;

    insert into app_private.transactions (
        id,
        user_id,
        account_id,
        category_id,
        subcategory_id,
        amount_cents,
        occurred_at,
        description,
        notes,
        import_batch_id,
        external_id,
        created_at,
        updated_at
    )
    select
        tx.transaction_id,
        v_user_id,
        tx.account_id,
        tx.category_id,
        tx.subcategory_id,
        tx.amount_cents,
        tx.occurred_at,
        tx.description,
        tx.notes,
        tx.batch_id,
        tx.external_id,
        v_now,
        v_now
    from pg_temp.import_insertable_transaction tx
    order by tx.occurred_at asc, tx.transaction_id asc;

    for v_account_id in
        select distinct tx.account_id
        from pg_temp.import_insertable_transaction tx
        where app_private.v1_is_credit_card_account(v_user_id, tx.account_id)
    loop
        perform app_private.v1_rebuild_card_statements(v_user_id, v_account_id, v_now);
    end loop;

    v_response := jsonb_build_object(
        'ok', true,
        'code', null,
        'imported_batch_ids', coalesce(
            (
                select jsonb_agg(batch.id order by batch.imported_at desc, batch.id desc)
                from app_private.import_batches batch
                where batch.user_id = v_user_id
                  and exists (
                      select 1
                      from pg_temp.import_batch_input input_batch
                      where input_batch.batch_id = batch.id
                  )
            ),
            '[]'::jsonb
        ),
        'imported_row_count', coalesce(
            (select count(*) from pg_temp.import_insertable_transaction),
            0
        ),
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
                    select distinct
                        row.batch_id,
                        row.external_id,
                        row.description,
                        row.occurred_at
                    from pg_temp.import_duplicate_row row
                ) duplicate_row
            ),
            '[]'::jsonb
        )
    );

    insert into app_private.import_commit_receipts (
        user_id,
        idempotency_key,
        response,
        created_at
    ) values (
        v_user_id,
        p_idempotency_key,
        v_response,
        v_now
    )
    on conflict (user_id, idempotency_key) do update
    set response = excluded.response;

    return v_response;
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

create or replace function api.v1_get_dashboard_summary(
    p_from_date date,
    p_to_date date,
    p_timezone_override text default null
)
returns table (
    total_balance_cents bigint,
    period_expense_cents bigint,
    period_income_cents bigint
)
language sql
security definer
set search_path = app_private, extensions
as $$
    with context as (
        select auth.uid() as user_id
    ),
    bounds as (
        select period.*
        from context
        cross join lateral app_private.v1_dashboard_period_bounds(
            context.user_id,
            p_from_date,
            p_to_date,
            p_timezone_override
        ) period
    ),
    period_totals as (
        select
            coalesce(sum(case
                when period_rows.kind = 'expense' then signed_amount
                else 0
            end), 0) as expense_cents,
            coalesce(sum(case
                when period_rows.kind = 'income' then signed_amount
                else 0
            end), 0) as income_cents
        from context
        cross join bounds
        left join lateral (
            select
                category.kind,
                txn.amount_cents as signed_amount
            from app_private.transactions txn
            join app_private.category_catalog category
                on category.id = txn.category_id
            where txn.user_id = context.user_id
              and txn.occurred_at >= bounds.from_utc
              and txn.occurred_at < bounds.to_utc_exclusive
              and category.kind in ('income', 'expense')
        ) period_rows on true
    ),
    lifetime_totals as (
        select
            coalesce(sum(case
                when lifetime_rows.kind = 'income' then signed_amount
                else 0
            end), 0) as income_cents,
            coalesce(sum(case
                when lifetime_rows.kind = 'expense' then signed_amount
                else 0
            end), 0) as expense_cents
        from context
        left join lateral (
            select
                category.kind,
                txn.amount_cents as signed_amount
            from app_private.transactions txn
            join app_private.category_catalog category
                on category.id = txn.category_id
            where txn.user_id = context.user_id
              and category.kind in ('income', 'expense')
        ) lifetime_rows on true
    ),
    initial_balance as (
        select
            coalesce(sum(account.initial_balance_cents), 0) as cents
        from context
        left join app_private.accounts account
            on account.user_id = context.user_id
           and account.archived = false
    )
    select
        initial_balance.cents
            + lifetime_totals.income_cents
            - lifetime_totals.expense_cents as total_balance_cents,
        period_totals.expense_cents as period_expense_cents,
        period_totals.income_cents as period_income_cents
    from initial_balance, lifetime_totals, period_totals
$$;

create or replace function api.v1_list_dashboard_expense_category_totals(
    p_from_date date,
    p_to_date date,
    p_timezone_override text default null
)
returns table (
    category_id uuid,
    category_name text,
    category_slug text,
    total_cents bigint
)
language sql
security definer
set search_path = app_private, extensions
as $$
    with context as (
        select auth.uid() as user_id
    ),
    bounds as (
        select period.*
        from context
        cross join lateral app_private.v1_dashboard_period_bounds(
            context.user_id,
            p_from_date,
            p_to_date,
            p_timezone_override
        ) period
    ),
    rows as (
        select
            coalesce(root.id, category.id) as category_id,
            coalesce(root.name, category.name) as category_name,
            coalesce(root.slug, category.slug) as category_slug,
            txn.amount_cents as signed_amount
        from context
        cross join bounds
        join app_private.transactions txn
            on txn.user_id = context.user_id
        join app_private.category_catalog category
            on category.id = txn.category_id
        left join app_private.category_catalog root
            on root.id = category.parent_id
        where txn.occurred_at >= bounds.from_utc
          and txn.occurred_at < bounds.to_utc_exclusive
          and category.kind = 'expense'
    )
    select
        rows.category_id,
        rows.category_name,
        rows.category_slug,
        sum(rows.signed_amount) as total_cents
    from rows
    group by rows.category_id, rows.category_name, rows.category_slug
    order by total_cents desc, rows.category_name asc
$$;

create or replace function api.v1_list_dashboard_expense_weekday_totals(
    p_from_date date,
    p_to_date date,
    p_timezone_override text default null
)
returns table (
    weekday integer,
    total_cents bigint,
    count bigint
)
language sql
security definer
set search_path = app_private, extensions
as $$
    with context as (
        select auth.uid() as user_id
    ),
    bounds as (
        select period.*
        from context
        cross join lateral app_private.v1_dashboard_period_bounds(
            context.user_id,
            p_from_date,
            p_to_date,
            p_timezone_override
        ) period
    )
    select
        (extract(dow from txn.occurred_at at time zone bounds.timezone_name)::integer + 1) as weekday,
        sum(txn.amount_cents) as total_cents,
        count(*)::bigint as count
    from context
    cross join bounds
    join app_private.transactions txn
        on txn.user_id = context.user_id
    join app_private.category_catalog category
        on category.id = txn.category_id
    where txn.occurred_at >= bounds.from_utc
      and txn.occurred_at < bounds.to_utc_exclusive
      and category.kind = 'expense'
    group by weekday
    order by weekday asc
$$;

create or replace function api.v1_list_dashboard_monthly_kind_totals(
    p_from_date date,
    p_to_date date,
    p_timezone_override text default null
)
returns table (
    month_start timestamptz,
    income_cents bigint,
    expense_cents bigint
)
language sql
security definer
set search_path = app_private, extensions
as $$
    with context as (
        select auth.uid() as user_id
    ),
    bounds as (
        select period.*
        from context
        cross join lateral app_private.v1_dashboard_period_bounds(
            context.user_id,
            p_from_date,
            p_to_date,
            p_timezone_override
        ) period
    ),
    rows as (
        select
            app_private.v1_utc_midnight(
                date_trunc(
                    'month',
                    txn.occurred_at at time zone bounds.timezone_name
                )::date
            ) as month_start,
            category.kind,
            txn.amount_cents as signed_amount
        from context
        cross join bounds
        join app_private.transactions txn
            on txn.user_id = context.user_id
        join app_private.category_catalog category
            on category.id = txn.category_id
        where txn.occurred_at >= bounds.from_utc
          and txn.occurred_at < bounds.to_utc_exclusive
          and category.kind in ('income', 'expense')
    )
    select
        rows.month_start,
        sum(case
            when rows.kind = 'income' then rows.signed_amount
            else 0
        end) as income_cents,
        sum(case
            when rows.kind = 'expense' then rows.signed_amount
            else 0
        end) as expense_cents
    from rows
    group by rows.month_start
    order by rows.month_start asc
$$;

do $$
declare
    v_row record;
begin
    for v_row in
        select account.user_id, account.id as account_id
        from pg_temp.legacy_refund_cleanup_account account
        where app_private.v1_is_credit_card_account(account.user_id, account.account_id)
    loop
        perform app_private.v1_rebuild_card_statements(v_row.user_id, v_row.account_id, timezone('utc', now()));
    end loop;
end;
$$;

revoke all on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) from public;
revoke all on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) from anon;
revoke all on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) from authenticated;
revoke all on function api.v1_list_statement_transactions(uuid) from public;
revoke all on function api.v1_list_statement_transactions(uuid) from anon;
revoke all on function api.v1_list_statement_transactions(uuid) from authenticated;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid) from public;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid) from anon;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid) from authenticated;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid) from public;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid) from anon;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid) from authenticated;
revoke all on function api.v1_delete_transaction(uuid) from public;
revoke all on function api.v1_delete_transaction(uuid) from anon;
revoke all on function api.v1_delete_transaction(uuid) from authenticated;
revoke all on function api.v1_commit_import(uuid, jsonb, jsonb) from public;
revoke all on function api.v1_commit_import(uuid, jsonb, jsonb) from anon;
revoke all on function api.v1_commit_import(uuid, jsonb, jsonb) from authenticated;
revoke all on function api.v1_delete_import_batch(uuid) from public;
revoke all on function api.v1_delete_import_batch(uuid) from anon;
revoke all on function api.v1_delete_import_batch(uuid) from authenticated;
revoke all on function api.v1_get_dashboard_summary(date, date, text) from public;
revoke all on function api.v1_get_dashboard_summary(date, date, text) from anon;
revoke all on function api.v1_get_dashboard_summary(date, date, text) from authenticated;
revoke all on function api.v1_list_dashboard_expense_category_totals(date, date, text) from public;
revoke all on function api.v1_list_dashboard_expense_category_totals(date, date, text) from anon;
revoke all on function api.v1_list_dashboard_expense_category_totals(date, date, text) from authenticated;
revoke all on function api.v1_list_dashboard_expense_weekday_totals(date, date, text) from public;
revoke all on function api.v1_list_dashboard_expense_weekday_totals(date, date, text) from anon;
revoke all on function api.v1_list_dashboard_expense_weekday_totals(date, date, text) from authenticated;
revoke all on function api.v1_list_dashboard_monthly_kind_totals(date, date, text) from public;
revoke all on function api.v1_list_dashboard_monthly_kind_totals(date, date, text) from anon;
revoke all on function api.v1_list_dashboard_monthly_kind_totals(date, date, text) from authenticated;

grant usage on schema api to authenticated;
grant execute on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) to authenticated;
grant execute on function api.v1_list_statement_transactions(uuid) to authenticated;
grant execute on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid) to authenticated;
grant execute on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid) to authenticated;
grant execute on function api.v1_delete_transaction(uuid) to authenticated;
grant execute on function api.v1_commit_import(uuid, jsonb, jsonb) to authenticated;
grant execute on function api.v1_delete_import_batch(uuid) to authenticated;
grant execute on function api.v1_get_dashboard_summary(date, date, text) to authenticated;
grant execute on function api.v1_list_dashboard_expense_category_totals(date, date, text) to authenticated;
grant execute on function api.v1_list_dashboard_expense_weekday_totals(date, date, text) to authenticated;
grant execute on function api.v1_list_dashboard_monthly_kind_totals(date, date, text) to authenticated;
