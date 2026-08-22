-- Ticket #19 rollback manual:
-- 1. grant insert, update, delete on table app_private.accounts to authenticated;
-- 2. grant insert, update, delete on table app_private.bank_accounts to authenticated;
-- 3. grant insert, update, delete on table app_private.credit_cards to authenticated;
-- 4. grant insert, update, delete on table app_private.credit_card_cycle_configs to authenticated;
-- 5. revoke execute on function api.v1_create_account(text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer) from authenticated;
-- 6. revoke execute on function api.v1_update_account(uuid, text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer, timestamptz) from authenticated;
-- 7. revoke execute on function api.v1_delete_account(uuid) from authenticated;
-- 8. drop function if exists api.v1_delete_account(uuid);
-- 9. drop function if exists api.v1_update_account(uuid, text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer, timestamptz);
-- 10. drop function if exists api.v1_create_account(text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer);
-- 11. revoke execute on function api.v1_list_accounts() from authenticated;
-- 12. drop function if exists api.v1_list_accounts();

create or replace function api.v1_list_accounts()
returns table (
    id uuid,
    type text,
    initial_balance_cents bigint,
    archived boolean,
    institution_id uuid,
    currency text,
    created_at timestamptz,
    updated_at timestamptz,
    branch_id text,
    account_number text,
    bank_created_at timestamptz,
    bank_updated_at timestamptz,
    card_last_four text,
    credit_limit_cents bigint,
    statement_closing_day integer,
    payment_due_day integer,
    card_created_at timestamptz,
    card_updated_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
    select
        a.id,
        a.type,
        a.initial_balance_cents,
        a.archived,
        a.institution_id,
        a.currency,
        a.created_at,
        a.updated_at,
        b.branch_id,
        b.account_number,
        b.created_at as bank_created_at,
        b.updated_at as bank_updated_at,
        c.card_last_four,
        c.credit_limit_cents,
        c.statement_closing_day,
        c.payment_due_day,
        c.created_at as card_created_at,
        c.updated_at as card_updated_at
    from app_private.accounts a
    left join app_private.bank_accounts b
        on b.user_id = a.user_id
       and b.account_id = a.id
    left join app_private.credit_cards c
        on c.user_id = a.user_id
       and c.account_id = a.id
    where a.user_id = auth.uid()
    order by a.type asc, a.created_at asc
$$;

create or replace function api.v1_create_account(
    p_type text,
    p_initial_balance_cents bigint,
    p_archived boolean,
    p_institution_id uuid,
    p_currency text,
    p_branch_id text default null,
    p_account_number text default null,
    p_card_last_four text default null,
    p_credit_limit_cents bigint default null,
    p_statement_closing_day integer default null,
    p_payment_due_day integer default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_account_id uuid;
    v_now timestamptz := timezone('utc', now());
    v_currency text := upper(trim(coalesce(p_currency, '')));
    v_branch_id text := nullif(trim(coalesce(p_branch_id, '')), '');
    v_account_number text := nullif(trim(coalesce(p_account_number, '')), '');
    v_card_last_four text := nullif(trim(coalesce(p_card_last_four, '')), '');
begin
    if v_user_id is null then
        return jsonb_build_object('ok', false, 'code', 'authentication_required');
    end if;

    if v_currency <> 'BRL' then
        return jsonb_build_object('ok', false, 'code', 'invalid_currency');
    end if;

    if p_institution_id is null or not exists (
        select 1
        from app_private.supported_institutions_catalog sic
        where sic.id = p_institution_id
          and p_type = any(sic.supported_account_types)
    ) then
        return jsonb_build_object('ok', false, 'code', 'unsupported_institution');
    end if;

    if p_type = 'checking' then
        if v_branch_id is null or v_account_number is null then
            return jsonb_build_object('ok', false, 'code', 'invalid_checking_account_details');
        end if;
    elseif p_type = 'creditCard' then
        if v_card_last_four is null
           or v_card_last_four !~ '^[0-9]{4}$'
           or p_statement_closing_day is null
           or p_statement_closing_day not between 1 and 31
           or p_payment_due_day is null
           or p_payment_due_day not between 1 and 31
           or (p_credit_limit_cents is not null and p_credit_limit_cents < 0)
        then
            return jsonb_build_object('ok', false, 'code', 'invalid_credit_card_details');
        end if;
    else
        return jsonb_build_object('ok', false, 'code', 'invalid_account_type');
    end if;

    insert into app_private.accounts (
        user_id,
        type,
        initial_balance_cents,
        archived,
        institution_id,
        currency,
        created_at,
        updated_at
    ) values (
        v_user_id,
        p_type,
        case when p_type = 'creditCard' then 0 else p_initial_balance_cents end,
        coalesce(p_archived, false),
        p_institution_id,
        v_currency,
        v_now,
        v_now
    )
    returning id into v_account_id;

    if p_type = 'checking' then
        insert into app_private.bank_accounts (
            user_id,
            account_id,
            branch_id,
            account_number,
            created_at,
            updated_at
        ) values (
            v_user_id,
            v_account_id,
            v_branch_id,
            v_account_number,
            v_now,
            v_now
        );
    else
        insert into app_private.credit_cards (
            user_id,
            account_id,
            card_last_four,
            credit_limit_cents,
            statement_closing_day,
            payment_due_day,
            created_at,
            updated_at
        ) values (
            v_user_id,
            v_account_id,
            v_card_last_four,
            p_credit_limit_cents,
            p_statement_closing_day,
            p_payment_due_day,
            v_now,
            v_now
        );

        insert into app_private.credit_card_cycle_configs (
            user_id,
            account_id,
            effective_from,
            statement_closing_day,
            payment_due_day,
            created_at
        ) values (
            v_user_id,
            v_account_id,
            v_now,
            p_statement_closing_day,
            p_payment_due_day,
            v_now
        );
    end if;

    return jsonb_build_object('ok', true, 'account_id', v_account_id);
end;
$$;

create or replace function api.v1_update_account(
    p_account_id uuid,
    p_type text,
    p_initial_balance_cents bigint,
    p_archived boolean,
    p_institution_id uuid,
    p_currency text,
    p_branch_id text default null,
    p_account_number text default null,
    p_card_last_four text default null,
    p_credit_limit_cents bigint default null,
    p_statement_closing_day integer default null,
    p_payment_due_day integer default null,
    p_cycle_effective_from timestamptz default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_now timestamptz := timezone('utc', now());
    v_currency text := upper(trim(coalesce(p_currency, '')));
    v_branch_id text := nullif(trim(coalesce(p_branch_id, '')), '');
    v_account_number text := nullif(trim(coalesce(p_account_number, '')), '');
    v_card_last_four text := nullif(trim(coalesce(p_card_last_four, '')), '');
begin
    if v_user_id is null then
        return jsonb_build_object('ok', false, 'code', 'authentication_required');
    end if;

    if not exists (
        select 1
        from app_private.accounts a
        where a.user_id = v_user_id
          and a.id = p_account_id
    ) then
        return jsonb_build_object('ok', false, 'code', 'account_not_found');
    end if;

    if v_currency <> 'BRL' then
        return jsonb_build_object('ok', false, 'code', 'invalid_currency');
    end if;

    if p_institution_id is null or not exists (
        select 1
        from app_private.supported_institutions_catalog sic
        where sic.id = p_institution_id
          and p_type = any(sic.supported_account_types)
    ) then
        return jsonb_build_object('ok', false, 'code', 'unsupported_institution');
    end if;

    if p_type = 'checking' then
        if v_branch_id is null or v_account_number is null then
            return jsonb_build_object('ok', false, 'code', 'invalid_checking_account_details');
        end if;
    elseif p_type = 'creditCard' then
        if v_card_last_four is null
           or v_card_last_four !~ '^[0-9]{4}$'
           or p_statement_closing_day is null
           or p_statement_closing_day not between 1 and 31
           or p_payment_due_day is null
           or p_payment_due_day not between 1 and 31
           or (p_credit_limit_cents is not null and p_credit_limit_cents < 0)
        then
            return jsonb_build_object('ok', false, 'code', 'invalid_credit_card_details');
        end if;
    else
        return jsonb_build_object('ok', false, 'code', 'invalid_account_type');
    end if;

    update app_private.accounts
    set
        type = p_type,
        initial_balance_cents = case when p_type = 'creditCard' then 0 else p_initial_balance_cents end,
        archived = coalesce(p_archived, false),
        institution_id = p_institution_id,
        currency = v_currency,
        updated_at = v_now
    where user_id = v_user_id
      and id = p_account_id;

    delete from app_private.credit_card_cycle_configs
    where user_id = v_user_id
      and account_id = p_account_id;

    delete from app_private.bank_accounts
    where user_id = v_user_id
      and account_id = p_account_id;

    delete from app_private.credit_cards
    where user_id = v_user_id
      and account_id = p_account_id;

    if p_type = 'checking' then
        insert into app_private.bank_accounts (
            user_id,
            account_id,
            branch_id,
            account_number,
            created_at,
            updated_at
        ) values (
            v_user_id,
            p_account_id,
            v_branch_id,
            v_account_number,
            v_now,
            v_now
        );
    else
        insert into app_private.credit_cards (
            user_id,
            account_id,
            card_last_four,
            credit_limit_cents,
            statement_closing_day,
            payment_due_day,
            created_at,
            updated_at
        ) values (
            v_user_id,
            p_account_id,
            v_card_last_four,
            p_credit_limit_cents,
            p_statement_closing_day,
            p_payment_due_day,
            v_now,
            v_now
        );

        insert into app_private.credit_card_cycle_configs (
            user_id,
            account_id,
            effective_from,
            statement_closing_day,
            payment_due_day,
            created_at
        ) values (
            v_user_id,
            p_account_id,
            coalesce(p_cycle_effective_from, v_now),
            p_statement_closing_day,
            p_payment_due_day,
            v_now
        );
    end if;

    return jsonb_build_object('ok', true, 'account_id', p_account_id);
end;
$$;

create or replace function api.v1_delete_account(
    p_account_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        return jsonb_build_object('ok', false, 'code', 'authentication_required');
    end if;

    if not exists (
        select 1
        from app_private.accounts a
        where a.user_id = v_user_id
          and a.id = p_account_id
    ) then
        return jsonb_build_object('ok', false, 'code', 'account_not_found');
    end if;

    if exists (
        select 1
        from app_private.transactions t
        where t.user_id = v_user_id
          and t.account_id = p_account_id
    ) or exists (
        select 1
        from app_private.statements s
        where s.user_id = v_user_id
          and s.account_id = p_account_id
    ) or exists (
        select 1
        from app_private.import_batches ib
        where ib.user_id = v_user_id
          and ib.account_id = p_account_id
    ) then
        return jsonb_build_object('ok', false, 'code', 'account_has_financial_history');
    end if;

    delete from app_private.accounts
    where user_id = v_user_id
      and id = p_account_id;

    return jsonb_build_object('ok', true, 'account_id', p_account_id);
end;
$$;

revoke all on function api.v1_list_accounts() from public;
revoke all on function api.v1_list_accounts() from anon;
revoke all on function api.v1_list_accounts() from authenticated;

revoke all on function api.v1_create_account(text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer) from public;
revoke all on function api.v1_create_account(text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer) from anon;
revoke all on function api.v1_create_account(text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer) from authenticated;

revoke all on function api.v1_update_account(uuid, text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer, timestamptz) from public;
revoke all on function api.v1_update_account(uuid, text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer, timestamptz) from anon;
revoke all on function api.v1_update_account(uuid, text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer, timestamptz) from authenticated;

revoke all on function api.v1_delete_account(uuid) from public;
revoke all on function api.v1_delete_account(uuid) from anon;
revoke all on function api.v1_delete_account(uuid) from authenticated;

grant execute on function api.v1_list_accounts() to authenticated;
grant execute on function api.v1_create_account(text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer) to authenticated;
grant execute on function api.v1_update_account(uuid, text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer, timestamptz) to authenticated;
grant execute on function api.v1_delete_account(uuid) to authenticated;

revoke insert, update, delete on table app_private.accounts from authenticated;
revoke insert, update, delete on table app_private.bank_accounts from authenticated;
revoke insert, update, delete on table app_private.credit_cards from authenticated;
revoke insert, update, delete on table app_private.credit_card_cycle_configs from authenticated;
