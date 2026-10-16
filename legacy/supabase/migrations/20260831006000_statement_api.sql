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
    origin_occurred_at timestamptz,
    purchase_type text,
    installment_index integer,
    installment_count integer,
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
        txn.origin_occurred_at,
        txn.purchase_type,
        txn.installment_index,
        txn.installment_count,
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


revoke all on function api.v1_list_statements() from public;
revoke all on function api.v1_list_statements() from anon;
revoke all on function api.v1_list_statements() from authenticated;
revoke all on function api.v1_list_statement_payments() from public;
revoke all on function api.v1_list_statement_payments() from anon;
revoke all on function api.v1_list_statement_payments() from authenticated;
revoke all on function api.v1_list_statement_transactions(uuid) from public;
revoke all on function api.v1_list_statement_transactions(uuid) from anon;
revoke all on function api.v1_list_statement_transactions(uuid) from authenticated;
revoke all on function api.v1_update_statement_dates(uuid, date, date) from public;
revoke all on function api.v1_update_statement_dates(uuid, date, date) from anon;
revoke all on function api.v1_update_statement_dates(uuid, date, date) from authenticated;

grant execute on function api.v1_list_statements() to authenticated;
grant execute on function api.v1_list_statement_payments() to authenticated;
grant execute on function api.v1_list_statement_transactions(uuid) to authenticated;
grant execute on function api.v1_update_statement_dates(uuid, date, date) to authenticated;
