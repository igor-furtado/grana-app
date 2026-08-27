-- ADR-0008 rollback manual:
-- 1. revoke execute on function api.v1_update_statement_dates(uuid, date, date) from authenticated;
-- 2. drop function if exists api.v1_update_statement_dates(uuid, date, date);
-- 3. drop function if exists app_private.v1_find_or_create_statement_for_card_entry(uuid, uuid, timestamptz, timestamptz);
-- 4. rerun migration `20260826151057_fix_statement_rebuild_clear_statement_links_first.sql`.

create or replace function app_private.v1_find_or_create_statement_for_card_entry(
    p_user_id uuid,
    p_account_id uuid,
    p_occurred_at timestamptz,
    p_reference_date timestamptz default timezone('utc', now())
)
returns uuid
language plpgsql
security definer
set search_path = app_private, extensions
as $$
declare
    v_transaction_day date := app_private.v1_local_date(p_user_id, p_occurred_at);
    v_statement_id uuid;
    v_cycle record;
    v_window record;
    v_now timestamptz := timezone('utc', now());
begin
    with statement_bounds as (
        select
            statement.id,
            (statement.closing_date at time zone 'UTC')::date as closing_day,
            coalesce(
                lag((statement.closing_date at time zone 'UTC')::date) over (
                    partition by statement.account_id
                    order by statement.closing_date asc, statement.created_at asc, statement.id asc
                ),
                ((statement.closing_date at time zone 'UTC')::date - interval '1 month')::date
            ) as previous_closing_day,
            statement.closing_date,
            statement.created_at
        from app_private.statements statement
        where statement.user_id = p_user_id
          and statement.account_id = p_account_id
    )
    select statement_bounds.id
    into v_statement_id
    from statement_bounds
    where statement_bounds.previous_closing_day < v_transaction_day
      and statement_bounds.closing_day >= v_transaction_day
    order by statement_bounds.closing_date asc, statement_bounds.created_at asc, statement_bounds.id asc
    limit 1;

    if v_statement_id is not null then
        return v_statement_id;
    end if;

    select
        card.statement_closing_day,
        card.payment_due_day
    into v_cycle
    from app_private.credit_cards card
    where card.user_id = p_user_id
      and card.account_id = p_account_id;

    if v_cycle.statement_closing_day is null then
        raise exception using message = 'missing_cycle_configuration';
    end if;

    select *
    into v_window
    from app_private.v1_resolve_statement_window(
        p_user_id,
        v_cycle.statement_closing_day,
        v_cycle.payment_due_day,
        p_occurred_at
    );

    select statement.id
    into v_statement_id
    from app_private.statements statement
    where statement.user_id = p_user_id
      and statement.account_id = p_account_id
      and statement.closing_date = v_window.closing_date
    limit 1;

    if v_statement_id is not null then
        return v_statement_id;
    end if;

    insert into app_private.statements (
        id,
        user_id,
        account_id,
        closing_date,
        due_date,
        net_amount_cents,
        credit_received_cents,
        payment_applied_cents,
        settled_at,
        created_at,
        updated_at
    ) values (
        gen_random_uuid(),
        p_user_id,
        p_account_id,
        v_window.closing_date,
        v_window.due_date,
        0,
        0,
        0,
        null,
        p_reference_date,
        v_now
    )
    returning id into v_statement_id;

    return v_statement_id;
end;
$$;

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
    v_purchase record;
    v_refunded_total bigint;
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
            refund.id,
            refund.account_id,
            refund.category_id,
            refund.subcategory_id,
            refund.amount_cents,
            refund.occurred_at,
            refund.refund_of_transaction_id
        from app_private.transactions refund
        join app_private.category_catalog category
            on category.id = refund.category_id
        where refund.user_id = p_user_id
          and refund.account_id = p_account_id
          and refund.refund_of_transaction_id is not null
          and category.kind <> 'transfer'
        order by refund.occurred_at asc, refund.id asc
    loop
        select
            purchase.id,
            purchase.account_id,
            purchase.category_id,
            purchase.subcategory_id,
            purchase.amount_cents,
            purchase.occurred_at,
            purchase.refund_of_transaction_id,
            category.kind
        into v_purchase
        from app_private.transactions purchase
        join app_private.category_catalog category
            on category.id = purchase.category_id
        where purchase.user_id = p_user_id
          and purchase.id = v_entry.refund_of_transaction_id;

        if v_purchase.id is null
           or v_purchase.account_id <> p_account_id
           or v_purchase.refund_of_transaction_id is not null
           or v_purchase.kind = 'transfer'
        then
            raise exception using message = 'invalid_refund';
        end if;

        if v_entry.occurred_at < v_purchase.occurred_at then
            raise exception using message = 'refund_before_purchase';
        end if;

        select coalesce(sum(refund.amount_cents), 0)
        into v_refunded_total
        from app_private.transactions refund
        where refund.user_id = p_user_id
          and refund.refund_of_transaction_id = v_purchase.id;

        if v_refunded_total > v_purchase.amount_cents then
            raise exception using message = 'refund_exceeds_purchase';
        end if;

        if v_entry.category_id is distinct from v_purchase.category_id
           or v_entry.subcategory_id is distinct from v_purchase.subcategory_id
        then
            update app_private.transactions
            set
                category_id = v_purchase.category_id,
                subcategory_id = v_purchase.subcategory_id,
                updated_at = v_now
            where user_id = p_user_id
              and id = v_entry.id;
        end if;
    end loop;

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
                when txn.refund_of_transaction_id is null then txn.amount_cents
                else -txn.amount_cents
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
    v_last_statement_id uuid;
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
      and txn.id = p_transaction_id
      and txn.destination_account_id = p_account_id;

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
                    when txn.refund_of_transaction_id is null then txn.amount_cents
                    else -txn.amount_cents
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
            id,
            user_id,
            statement_id,
            transaction_id,
            applied_amount_cents,
            created_at,
            updated_at
        ) values (
            gen_random_uuid(),
            p_user_id,
            v_statement.id,
            p_transaction_id,
            v_apply,
            v_payment.occurred_at,
            p_reference_date
        );

        v_remaining := v_remaining - v_apply;
        v_last_statement_id := v_statement.id;
    end loop;

    if v_remaining > 0 and v_last_statement_id is not null then
        insert into app_private.statement_payments (
            id,
            user_id,
            statement_id,
            transaction_id,
            applied_amount_cents,
            created_at,
            updated_at
        ) values (
            gen_random_uuid(),
            p_user_id,
            v_last_statement_id,
            p_transaction_id,
            v_remaining,
            v_payment.occurred_at,
            p_reference_date
        );
        v_remaining := 0;
    end if;

    if v_remaining <> 0 then
        raise exception using message = 'unapplied_payment';
    end if;
end;
$$;

drop function if exists api.v1_update_statement_dates(uuid, timestamptz, timestamptz);

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
                when category.kind <> 'transfer'
                     and txn.refund_of_transaction_id is null then txn.amount_cents
                when category.kind <> 'transfer' then -txn.amount_cents
                else 0
            end), 0) as net_amount_cents
        from app_private.statements statement
        left join app_private.transactions txn
            on txn.user_id = statement.user_id
           and txn.statement_id = statement.id
        left join app_private.category_catalog category
            on category.id = txn.category_id
           and category.kind <> 'transfer'
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

revoke all on function api.v1_update_statement_dates(uuid, date, date) from public;
revoke all on function api.v1_update_statement_dates(uuid, date, date) from anon;
revoke all on function api.v1_update_statement_dates(uuid, date, date) from authenticated;

grant execute on function api.v1_update_statement_dates(uuid, date, date) to authenticated;

create or replace function api.v1_create_transaction(
    p_account_id uuid,
    p_category_id uuid,
    p_subcategory_id uuid,
    p_amount_cents bigint,
    p_occurred_at timestamptz,
    p_description text,
    p_notes text,
    p_destination_account_id uuid,
    p_refund_of_transaction_id uuid
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

    if p_refund_of_transaction_id is not null and (
        v_account_type <> 'creditCard'
        or v_category_kind = 'transfer'
        or p_destination_account_id is not null
    ) then
        return jsonb_build_object('ok', false, 'code', 'invalid_refund');
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
            refund_of_transaction_id,
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
            p_refund_of_transaction_id,
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
                'invalid_refund',
                'refund_before_purchase',
                'refund_exceeds_purchase',
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

create or replace function api.v1_update_transaction(
    p_transaction_id uuid,
    p_account_id uuid,
    p_category_id uuid,
    p_subcategory_id uuid,
    p_amount_cents bigint,
    p_occurred_at timestamptz,
    p_description text,
    p_notes text,
    p_destination_account_id uuid,
    p_refund_of_transaction_id uuid
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

    if exists (
        select 1
        from app_private.transactions linked
        where linked.user_id = v_user_id
          and linked.refund_of_transaction_id = p_transaction_id
    ) then
        return jsonb_build_object('ok', false, 'code', 'linked_refunds_exist');
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

    if p_refund_of_transaction_id is not null and (
        v_account_type <> 'creditCard'
        or v_category_kind = 'transfer'
        or p_destination_account_id is not null
    ) then
        return jsonb_build_object('ok', false, 'code', 'invalid_refund');
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
            refund_of_transaction_id = p_refund_of_transaction_id,
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
                'invalid_refund',
                'refund_before_purchase',
                'refund_exceeds_purchase',
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
