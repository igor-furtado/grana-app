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

end;
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
