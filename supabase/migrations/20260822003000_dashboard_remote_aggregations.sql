-- Ticket #22 rollback manual:
-- 1. revoke execute on function api.v1_list_dashboard_monthly_kind_totals(date, date, text) from authenticated;
-- 2. revoke execute on function api.v1_list_dashboard_expense_weekday_totals(date, date, text) from authenticated;
-- 3. revoke execute on function api.v1_list_dashboard_expense_category_totals(date, date, text) from authenticated;
-- 4. revoke execute on function api.v1_get_dashboard_summary(date, date, text) from authenticated;
-- 5. revoke execute on function api.v1_get_profile_timezone() from authenticated;
-- 6. drop function if exists api.v1_list_dashboard_monthly_kind_totals(date, date, text);
-- 7. drop function if exists api.v1_list_dashboard_expense_weekday_totals(date, date, text);
-- 8. drop function if exists api.v1_list_dashboard_expense_category_totals(date, date, text);
-- 9. drop function if exists api.v1_get_dashboard_summary(date, date, text);
-- 10. drop function if exists api.v1_get_profile_timezone();
-- 11. drop function if exists app_private.v1_dashboard_period_bounds(uuid, date, date, text);
-- 12. drop function if exists app_private.v1_dashboard_timezone(uuid, text);

create or replace function app_private.v1_dashboard_timezone(
    p_user_id uuid,
    p_timezone_override text default null
)
returns text
language sql
stable
security definer
set search_path = app_private, extensions
as $$
    select coalesce(
        nullif(trim(p_timezone_override), ''),
        app_private.v1_user_timezone(p_user_id)
    )
$$;

create or replace function app_private.v1_dashboard_period_bounds(
    p_user_id uuid,
    p_from_date date,
    p_to_date date,
    p_timezone_override text default null
)
returns table (
    timezone_name text,
    from_utc timestamptz,
    to_utc_exclusive timestamptz
)
language sql
stable
security definer
set search_path = app_private, extensions
as $$
    select
        resolved.timezone_name,
        (p_from_date::timestamp at time zone resolved.timezone_name) as from_utc,
        ((p_to_date + 1)::timestamp at time zone resolved.timezone_name) as to_utc_exclusive
    from (
        select app_private.v1_dashboard_timezone(
            p_user_id,
            p_timezone_override
        ) as timezone_name
    ) resolved
$$;

create or replace function api.v1_get_profile_timezone()
returns table (
    timezone text
)
language sql
security definer
set search_path = app_private, extensions
as $$
    select app_private.v1_user_timezone(auth.uid()) as timezone
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
                case
                    when txn.refund_of_transaction_id is null then txn.amount_cents
                    else -txn.amount_cents
                end as signed_amount
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
                case
                    when txn.refund_of_transaction_id is null then txn.amount_cents
                    else -txn.amount_cents
                end as signed_amount
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
            case
                when txn.refund_of_transaction_id is null then txn.amount_cents
                else -txn.amount_cents
            end as signed_amount
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
        sum(case
            when txn.refund_of_transaction_id is null then txn.amount_cents
            else -txn.amount_cents
        end) as total_cents,
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
            case
                when txn.refund_of_transaction_id is null then txn.amount_cents
                else -txn.amount_cents
            end as signed_amount
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

revoke all on function api.v1_get_dashboard_summary(date, date, text) from public;
revoke all on function api.v1_get_dashboard_summary(date, date, text) from anon;
revoke all on function api.v1_get_dashboard_summary(date, date, text) from authenticated;

revoke all on function api.v1_get_profile_timezone() from public;
revoke all on function api.v1_get_profile_timezone() from anon;
revoke all on function api.v1_get_profile_timezone() from authenticated;

revoke all on function api.v1_list_dashboard_expense_category_totals(date, date, text) from public;
revoke all on function api.v1_list_dashboard_expense_category_totals(date, date, text) from anon;
revoke all on function api.v1_list_dashboard_expense_category_totals(date, date, text) from authenticated;

revoke all on function api.v1_list_dashboard_expense_weekday_totals(date, date, text) from public;
revoke all on function api.v1_list_dashboard_expense_weekday_totals(date, date, text) from anon;
revoke all on function api.v1_list_dashboard_expense_weekday_totals(date, date, text) from authenticated;

revoke all on function api.v1_list_dashboard_monthly_kind_totals(date, date, text) from public;
revoke all on function api.v1_list_dashboard_monthly_kind_totals(date, date, text) from anon;
revoke all on function api.v1_list_dashboard_monthly_kind_totals(date, date, text) from authenticated;

grant execute on function api.v1_get_profile_timezone() to authenticated;
grant execute on function api.v1_get_dashboard_summary(date, date, text) to authenticated;
grant execute on function api.v1_list_dashboard_expense_category_totals(date, date, text) to authenticated;
grant execute on function api.v1_list_dashboard_expense_weekday_totals(date, date, text) to authenticated;
grant execute on function api.v1_list_dashboard_monthly_kind_totals(date, date, text) to authenticated;
