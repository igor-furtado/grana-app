-- Ticket #21 rollback manual:
-- 1. revoke execute on function api.v1_list_statements() from authenticated;
-- 2. revoke execute on function api.v1_list_statement_payments() from authenticated;
-- 3. revoke execute on function api.v1_list_statement_transactions(uuid) from authenticated;
-- 4. drop function if exists api.v1_list_statement_transactions(uuid);
-- 5. drop function if exists api.v1_list_statement_payments();
-- 6. drop function if exists api.v1_list_statements();
-- 7. drop function if exists app_private.v1_rebuild_card_statements(uuid, uuid, timestamptz);
-- 8. drop function if exists app_private.v1_is_credit_card_account(uuid, uuid);
-- 9. drop function if exists app_private.v1_resolve_statement_window(uuid, integer, integer, timestamptz);
-- 10. drop function if exists app_private.v1_utc_midnight(date);
-- 11. drop function if exists app_private.v1_make_month_day(integer, integer, integer);
-- 12. drop function if exists app_private.v1_local_date(uuid, timestamptz);
-- 13. drop function if exists app_private.v1_user_timezone(uuid);
-- 14. rerun migration `20260821230000_basic_transaction_remote_contracts.sql`.

create or replace function app_private.v1_user_timezone(
    p_user_id uuid
)
returns text
language sql
stable
security definer
set search_path = app_private, extensions
as $$
    select coalesce(profile.timezone, 'UTC')
    from app_private.user_profiles profile
    where profile.user_id = p_user_id
$$;

create or replace function app_private.v1_local_date(
    p_user_id uuid,
    p_instant timestamptz
)
returns date
language sql
stable
security definer
set search_path = app_private, extensions
as $$
    select (p_instant at time zone app_private.v1_user_timezone(p_user_id))::date
$$;

create or replace function app_private.v1_make_month_day(
    p_year integer,
    p_month integer,
    p_preferred_day integer
)
returns date
language plpgsql
immutable
security definer
set search_path = app_private, extensions
as $$
declare
    v_month_start date := make_date(p_year, p_month, 1);
    v_last_day integer := extract(day from (date_trunc('month', v_month_start) + interval '1 month - 1 day'))::integer;
begin
    return make_date(p_year, p_month, least(p_preferred_day, v_last_day));
end;
$$;

create or replace function app_private.v1_utc_midnight(
    p_day date
)
returns timestamptz
language sql
immutable
security definer
set search_path = app_private, extensions
as $$
    select make_timestamptz(
        extract(year from p_day)::integer,
        extract(month from p_day)::integer,
        extract(day from p_day)::integer,
        0,
        0,
        0,
        'UTC'
    )
$$;

create or replace function app_private.v1_resolve_statement_window(
    p_user_id uuid,
    p_closing_day integer,
    p_payment_due_day integer,
    p_occurred_at timestamptz
)
returns table (
    opening_date timestamptz,
    closing_date timestamptz,
    due_date timestamptz
)
language plpgsql
stable
security definer
set search_path = app_private, extensions
as $$
declare
    v_transaction_day date := app_private.v1_local_date(p_user_id, p_occurred_at);
    v_closing_day date;
    v_due_day date;
    v_previous_closing date;
begin
    v_closing_day := app_private.v1_make_month_day(
        extract(year from v_transaction_day)::integer,
        extract(month from v_transaction_day)::integer,
        p_closing_day
    );

    if v_transaction_day > v_closing_day then
        v_closing_day := app_private.v1_make_month_day(
            extract(year from (v_transaction_day + interval '1 month'))::integer,
            extract(month from (v_transaction_day + interval '1 month'))::integer,
            p_closing_day
        );
    end if;

    v_due_day := app_private.v1_make_month_day(
        extract(year from v_closing_day)::integer,
        extract(month from v_closing_day)::integer,
        p_payment_due_day
    );
    if v_due_day <= v_closing_day then
        v_due_day := app_private.v1_make_month_day(
            extract(year from (v_closing_day + interval '1 month'))::integer,
            extract(month from (v_closing_day + interval '1 month'))::integer,
            p_payment_due_day
        );
    end if;

    v_previous_closing := app_private.v1_make_month_day(
        extract(year from (v_closing_day - interval '1 month'))::integer,
        extract(month from (v_closing_day - interval '1 month'))::integer,
        p_closing_day
    );

    opening_date := app_private.v1_utc_midnight(v_previous_closing + 1);
    closing_date := app_private.v1_utc_midnight(v_closing_day);
    due_date := app_private.v1_utc_midnight(v_due_day);
    return next;
end;
$$;

create or replace function app_private.v1_is_credit_card_account(
    p_user_id uuid,
    p_account_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = app_private, extensions
as $$
    select exists (
        select 1
        from app_private.accounts a
        where a.user_id = p_user_id
          and a.id = p_account_id
          and a.type = 'creditCard'
    )
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
    v_reference_local date := app_private.v1_local_date(p_user_id, p_reference_date);
    v_entry record;
    v_cycle record;
    v_window record;
    v_existing record;
    v_work record;
    v_purchase record;
    v_refunded_total bigint;
    v_next_statement_id uuid;
    v_excess bigint;
    v_remaining bigint;
    v_debt bigint;
    v_effective_delta bigint;
begin
    if not app_private.v1_is_credit_card_account(p_user_id, p_account_id) then
        return;
    end if;

    drop table if exists pg_temp.statement_work;
    create temporary table pg_temp.statement_work (
        idx integer,
        statement_id uuid primary key,
        closing_date timestamptz not null,
        due_date timestamptz not null,
        created_at timestamptz not null,
        first_entry_date timestamptz,
        net_cents bigint not null default 0,
        credit_received_cents bigint not null default 0,
        payment_applied_cents bigint not null default 0,
        coverage_date timestamptz,
        settled_at timestamptz
    ) on commit drop;

    drop table if exists pg_temp.statement_tx_map;
    create temporary table pg_temp.statement_tx_map (
        transaction_id uuid primary key,
        statement_id uuid not null
    ) on commit drop;

    drop table if exists pg_temp.statement_event;
    create temporary table pg_temp.statement_event (
        event_date timestamptz not null,
        priority integer not null,
        tie_breaker text not null,
        kind text not null,
        statement_id uuid,
        transaction_id uuid,
        amount_cents bigint,
        net_delta_cents bigint
    ) on commit drop;

    drop table if exists pg_temp.statement_payment_allocation;
    create temporary table pg_temp.statement_payment_allocation (
        statement_id uuid not null,
        transaction_id uuid not null,
        amount_cents bigint not null,
        occurred_at timestamptz not null
    ) on commit drop;

    drop table if exists pg_temp.statement_credit_allocation;
    create temporary table pg_temp.statement_credit_allocation (
        source_statement_id uuid not null,
        destination_statement_id uuid not null,
        amount_cents bigint not null,
        occurred_at timestamptz not null
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
            card_entry.amount_cents,
            card_entry.occurred_at,
            card_entry.refund_of_transaction_id
        from app_private.transactions card_entry
        join app_private.category_catalog category
            on category.id = card_entry.category_id
        where card_entry.user_id = p_user_id
          and card_entry.account_id = p_account_id
          and category.kind <> 'transfer'
        order by card_entry.occurred_at asc, card_entry.id asc
    loop
        select
            cycle.statement_closing_day,
            cycle.payment_due_day
        into v_cycle
        from app_private.credit_card_cycle_configs cycle
        where cycle.user_id = p_user_id
          and cycle.account_id = p_account_id
          and cycle.effective_from <= v_entry.occurred_at
        order by cycle.effective_from desc
        limit 1;

        if v_cycle.statement_closing_day is null then
            select
                card.statement_closing_day,
                card.payment_due_day
            into v_cycle
            from app_private.credit_cards card
            where card.user_id = p_user_id
              and card.account_id = p_account_id;
        end if;

        if v_cycle.statement_closing_day is null then
            raise exception using message = 'missing_cycle_configuration';
        end if;

        select *
        into v_window
        from app_private.v1_resolve_statement_window(
            p_user_id,
            v_cycle.statement_closing_day,
            v_cycle.payment_due_day,
            v_entry.occurred_at
        );

        select
            statement.id,
            statement.created_at
        into v_existing
        from app_private.statements statement
        where statement.user_id = p_user_id
          and statement.account_id = p_account_id
          and statement.closing_date = v_window.closing_date
        limit 1;

        insert into pg_temp.statement_work (
            idx,
            statement_id,
            closing_date,
            due_date,
            created_at
        )
        select
            null,
            coalesce(v_existing.id, gen_random_uuid()),
            v_window.closing_date,
            v_window.due_date,
            coalesce(v_existing.created_at, p_reference_date)
        where not exists (
            select 1
            from pg_temp.statement_work work
            where work.closing_date = v_window.closing_date
        );

        insert into pg_temp.statement_tx_map (
            transaction_id,
            statement_id
        )
        select
            v_entry.id,
            work.statement_id
        from pg_temp.statement_work work
        where work.closing_date = v_window.closing_date
        on conflict (transaction_id) do update
        set statement_id = excluded.statement_id;

        update pg_temp.statement_work
        set first_entry_date = case
            when first_entry_date is null then v_entry.occurred_at
            else least(first_entry_date, v_entry.occurred_at)
        end
        where closing_date = v_window.closing_date;

        v_effective_delta := case
            when v_entry.refund_of_transaction_id is null then v_entry.amount_cents
            else -v_entry.amount_cents
        end;

        insert into pg_temp.statement_event (
            event_date,
            priority,
            tie_breaker,
            kind,
            statement_id,
            transaction_id,
            net_delta_cents
        )
        select
            v_entry.occurred_at,
            0,
            v_entry.id::text,
            'card_entry',
            tx_map.statement_id,
            v_entry.id,
            v_effective_delta
        from pg_temp.statement_tx_map tx_map
        where tx_map.transaction_id = v_entry.id;
    end loop;

    with ordered as (
        select
            work.statement_id,
            row_number() over (order by work.closing_date asc) as idx
        from pg_temp.statement_work work
    )
    update pg_temp.statement_work work
    set idx = ordered.idx
    from ordered
    where ordered.statement_id = work.statement_id;

    insert into pg_temp.statement_event (
        event_date,
        priority,
        tie_breaker,
        kind,
        statement_id
    )
    select
        work.closing_date + interval '1 day',
        1,
        work.statement_id::text,
        'closing',
        work.statement_id
    from pg_temp.statement_work work
    where v_reference_local > app_private.v1_local_date(p_user_id, work.closing_date);

    insert into pg_temp.statement_event (
        event_date,
        priority,
        tie_breaker,
        kind,
        transaction_id,
        amount_cents
    )
    select
        payment.occurred_at,
        2,
        payment.id::text,
        'payment',
        payment.id,
        payment.amount_cents
    from app_private.transactions payment
    join app_private.category_catalog category
        on category.id = payment.category_id
    where payment.user_id = p_user_id
      and payment.destination_account_id = p_account_id
      and category.kind = 'transfer';

    for v_entry in
        select *
        from pg_temp.statement_event
        order by event_date asc, priority asc, tie_breaker asc
    loop
        if v_entry.kind = 'card_entry' then
            update pg_temp.statement_work
            set net_cents = net_cents + coalesce(v_entry.net_delta_cents, 0)
            where statement_id = v_entry.statement_id;
        elseif v_entry.kind = 'closing' then
            select *
            into v_work
            from pg_temp.statement_work work
            where work.statement_id = v_entry.statement_id;

            v_excess := greatest(
                0,
                v_work.credit_received_cents + v_work.payment_applied_cents - v_work.net_cents
            );

            if v_excess > 0 then
                select next_work.statement_id
                into v_next_statement_id
                from pg_temp.statement_work next_work
                where next_work.idx = v_work.idx + 1;

                if v_next_statement_id is not null then
                    update pg_temp.statement_work
                    set
                        credit_received_cents = credit_received_cents + v_excess,
                        coverage_date = case
                            when coverage_date is null then v_entry.event_date
                            else greatest(coverage_date, v_entry.event_date)
                        end
                    where statement_id = v_next_statement_id;

                    insert into pg_temp.statement_credit_allocation (
                        source_statement_id,
                        destination_statement_id,
                        amount_cents,
                        occurred_at
                    ) values (
                        v_work.statement_id,
                        v_next_statement_id,
                        v_excess,
                        v_entry.event_date
                    );
                end if;
            end if;

            select *
            into v_work
            from pg_temp.statement_work work
            where work.statement_id = v_entry.statement_id;

            if v_work.net_cents > 0
               and v_work.credit_received_cents + v_work.payment_applied_cents >= v_work.net_cents
               and v_entry.event_date >= v_work.closing_date
            then
                update pg_temp.statement_work
                set settled_at = greatest(
                    closing_date,
                    coalesce(coverage_date, v_entry.event_date)
                )
                where statement_id = v_work.statement_id;
            end if;
        else
            v_remaining := coalesce(v_entry.amount_cents, 0);

            for v_work in
                select *
                from pg_temp.statement_work work
                order by work.idx asc
            loop
                exit when v_remaining <= 0;

                if v_work.first_entry_date is null
                   or v_work.first_entry_date > v_entry.event_date
                then
                    continue;
                end if;

                v_debt := greatest(
                    0,
                    v_work.net_cents - v_work.credit_received_cents - v_work.payment_applied_cents
                );

                if v_debt <= 0 then
                    continue;
                end if;

                v_excess := least(v_debt, v_remaining);

                update pg_temp.statement_work
                set
                    payment_applied_cents = payment_applied_cents + v_excess,
                    coverage_date = case
                        when coverage_date is null then v_entry.event_date
                        else greatest(coverage_date, v_entry.event_date)
                    end
                where statement_id = v_work.statement_id;

                insert into pg_temp.statement_payment_allocation (
                    statement_id,
                    transaction_id,
                    amount_cents,
                    occurred_at
                ) values (
                    v_work.statement_id,
                    v_entry.transaction_id,
                    v_excess,
                    v_entry.event_date
                );

                v_remaining := v_remaining - v_excess;

                select *
                into v_work
                from pg_temp.statement_work work
                where work.statement_id = v_work.statement_id;

                if v_work.net_cents > 0
                   and v_work.credit_received_cents + v_work.payment_applied_cents >= v_work.net_cents
                   and v_entry.event_date >= v_work.closing_date
                then
                    update pg_temp.statement_work
                    set settled_at = greatest(
                        closing_date,
                        coalesce(coverage_date, v_entry.event_date)
                    )
                    where statement_id = v_work.statement_id;
                end if;
            end loop;

            if v_remaining <> 0 then
                raise exception using message = 'unapplied_payment';
            end if;
        end if;
    end loop;

    delete from app_private.statement_payments payment
    using app_private.statements statement
    where payment.user_id = p_user_id
      and statement.user_id = p_user_id
      and statement.account_id = p_account_id
      and payment.statement_id = statement.id;

    delete from app_private.statement_credit_applications credit
    using app_private.statements statement
    where credit.user_id = p_user_id
      and statement.user_id = p_user_id
      and statement.account_id = p_account_id
      and (
          credit.source_statement_id = statement.id
          or credit.destination_statement_id = statement.id
      );

    delete from app_private.statements
    where user_id = p_user_id
      and account_id = p_account_id;

    update app_private.transactions
    set statement_id = null
    where user_id = p_user_id
      and account_id = p_account_id;

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
    )
    select
        work.statement_id,
        p_user_id,
        p_account_id,
        work.closing_date,
        work.due_date,
        work.net_cents,
        work.credit_received_cents,
        work.payment_applied_cents,
        work.settled_at,
        work.created_at,
        p_reference_date
    from pg_temp.statement_work work
    order by work.closing_date asc;

    update app_private.transactions txn
    set statement_id = tx_map.statement_id
    from pg_temp.statement_tx_map tx_map
    where txn.user_id = p_user_id
      and txn.id = tx_map.transaction_id;

    insert into app_private.statement_payments (
        id,
        user_id,
        statement_id,
        transaction_id,
        applied_amount_cents,
        created_at,
        updated_at
    )
    select
        gen_random_uuid(),
        p_user_id,
        allocation.statement_id,
        allocation.transaction_id,
        allocation.amount_cents,
        allocation.occurred_at,
        p_reference_date
    from pg_temp.statement_payment_allocation allocation;

    insert into app_private.statement_credit_applications (
        id,
        user_id,
        source_statement_id,
        destination_statement_id,
        applied_amount_cents,
        created_at
    )
    select
        gen_random_uuid(),
        p_user_id,
        allocation.source_statement_id,
        allocation.destination_statement_id,
        allocation.amount_cents,
        allocation.occurred_at
    from pg_temp.statement_credit_allocation allocation;
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
    select
        statement.id,
        statement.account_id,
        statement.closing_date,
        statement.due_date,
        statement.net_amount_cents,
        statement.credit_received_cents,
        statement.payment_applied_cents,
        statement.settled_at,
        statement.created_at,
        statement.updated_at
    from app_private.statements statement
    where statement.user_id = auth.uid()
    order by statement.closing_date desc, statement.created_at desc, statement.id desc
$$;

create or replace function api.v1_list_statement_payments()
returns table (
    id uuid,
    statement_id uuid,
    transaction_id uuid,
    applied_amount_cents bigint,
    created_at timestamptz,
    updated_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
    select
        payment.id,
        payment.statement_id,
        payment.transaction_id,
        payment.applied_amount_cents,
        payment.created_at,
        payment.updated_at
    from app_private.statement_payments payment
    where payment.user_id = auth.uid()
    order by payment.created_at desc, payment.id desc
$$;

create or replace function api.v1_list_statement_transactions(
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
    refund_of_transaction_id uuid,
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
        txn.refund_of_transaction_id,
        txn.created_at,
        txn.updated_at
    from app_private.transactions txn
    where txn.user_id = auth.uid()
      and txn.statement_id = p_statement_id
    order by txn.occurred_at desc, txn.created_at desc, txn.id desc
$$;

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
    v_current record;
    v_now timestamptz := timezone('utc', now());
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

    begin
        delete from app_private.transactions
        where user_id = v_user_id
          and id = p_transaction_id;

        if app_private.v1_is_credit_card_account(v_user_id, v_current.account_id) then
            perform app_private.v1_rebuild_card_statements(v_user_id, v_current.account_id, v_now);
        end if;

        if v_current.destination_account_id is not null
           and app_private.v1_is_credit_card_account(v_user_id, v_current.destination_account_id)
        then
            perform app_private.v1_rebuild_card_statements(v_user_id, v_current.destination_account_id, v_now);
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

revoke all on function api.v1_list_statements() from public;
revoke all on function api.v1_list_statements() from anon;
revoke all on function api.v1_list_statements() from authenticated;

revoke all on function api.v1_list_statement_payments() from public;
revoke all on function api.v1_list_statement_payments() from anon;
revoke all on function api.v1_list_statement_payments() from authenticated;

revoke all on function api.v1_list_statement_transactions(uuid) from public;
revoke all on function api.v1_list_statement_transactions(uuid) from anon;
revoke all on function api.v1_list_statement_transactions(uuid) from authenticated;

revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from public;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from anon;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from authenticated;

revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from public;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from anon;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from authenticated;

revoke all on function api.v1_delete_transaction(uuid) from public;
revoke all on function api.v1_delete_transaction(uuid) from anon;
revoke all on function api.v1_delete_transaction(uuid) from authenticated;

grant execute on function api.v1_list_statements() to authenticated;
grant execute on function api.v1_list_statement_payments() to authenticated;
grant execute on function api.v1_list_statement_transactions(uuid) to authenticated;
grant execute on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) to authenticated;
grant execute on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) to authenticated;
grant execute on function api.v1_delete_transaction(uuid) to authenticated;

revoke insert, update, delete on table app_private.transactions from authenticated;
revoke insert, update, delete on table app_private.statements from authenticated;
revoke insert, update, delete on table app_private.statement_payments from authenticated;
revoke insert, update, delete on table app_private.statement_credit_applications from authenticated;
