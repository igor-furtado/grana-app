-- Rollback manual:
-- 1. Remover dependências de contas investment, globais, nickname e bank_name.
-- 2. Restaurar as versões anteriores das funções api.v1_list_accounts,
--    api.v1_create_account e api.v1_update_account.
-- 3. Remover constraints novas e colunas adicionadas nesta migration.
-- 4. Restaurar supported_account_types anteriores no catálogo de instituições.

alter table app_private.accounts
    drop constraint if exists accounts_type_check,
    drop constraint if exists accounts_currency_check;

alter table app_private.accounts
    add column if not exists territorial_scope text not null default 'brazilian',
    add column if not exists nickname text;

alter table app_private.bank_accounts
    add column if not exists bank_name text;

alter table app_private.accounts
    add constraint accounts_type_check
        check (type in ('checking', 'creditCard', 'investment')),
    add constraint accounts_territorial_scope_check
        check (territorial_scope in ('brazilian', 'global')),
    add constraint accounts_currency_by_scope_check
        check (
            (territorial_scope = 'brazilian' and currency = 'BRL')
            or (territorial_scope = 'global' and currency = 'USD')
        );

update app_private.supported_institutions_catalog
set supported_account_types = array['checking', 'creditCard', 'investment']::text[],
    updated_at = timezone('utc', now())
where code = '077';

update app_private.supported_institutions_catalog
set supported_account_types = array['checking', 'investment']::text[],
    updated_at = timezone('utc', now())
where code = '102';

drop function if exists api.v1_list_accounts();
drop function if exists api.v1_create_account(text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer);
drop function if exists api.v1_update_account(uuid, text, bigint, boolean, uuid, text, text, text, text, bigint, integer, integer, timestamptz);

create or replace function api.v1_list_accounts()
returns table (
    id uuid,
    type text,
    territorial_scope text,
    nickname text,
    initial_balance_cents bigint,
    archived boolean,
    institution_id uuid,
    currency text,
    created_at timestamptz,
    updated_at timestamptz,
    branch_id text,
    account_number text,
    bank_name text,
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
        a.territorial_scope,
        a.nickname,
        a.initial_balance_cents,
        a.archived,
        a.institution_id,
        a.currency,
        a.created_at,
        a.updated_at,
        b.branch_id,
        b.account_number,
        b.bank_name,
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
    p_territorial_scope text,
    p_nickname text,
    p_initial_balance_cents bigint,
    p_archived boolean,
    p_institution_id uuid,
    p_currency text,
    p_branch_id text default null,
    p_account_number text default null,
    p_bank_name text default null,
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
    v_scope text := nullif(trim(coalesce(p_territorial_scope, '')), '');
    v_nickname text := nullif(trim(coalesce(p_nickname, '')), '');
    v_currency text;
    v_branch_id text := nullif(trim(coalesce(p_branch_id, '')), '');
    v_account_number text := nullif(trim(coalesce(p_account_number, '')), '');
    v_bank_name text := nullif(trim(coalesce(p_bank_name, '')), '');
    v_card_last_four text := nullif(trim(coalesce(p_card_last_four, '')), '');
begin
    if v_user_id is null then
        return jsonb_build_object('ok', false, 'code', 'authentication_required');
    end if;

    if v_scope not in ('brazilian', 'global') then
        return jsonb_build_object('ok', false, 'code', 'invalid_territorial_scope');
    end if;

    v_currency := upper(trim(coalesce(p_currency, '')));
    if v_scope = 'brazilian' and v_currency = '' then
        v_currency := 'BRL';
    end if;

    if (v_scope = 'brazilian' and v_currency <> 'BRL')
        or (v_scope = 'global' and v_currency <> 'USD')
    then
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

    if p_type in ('checking', 'investment') then
        if v_account_number is null
            or (v_scope = 'global' and v_bank_name is null)
        then
            return jsonb_build_object('ok', false, 'code', 'invalid_account_identity');
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
        territorial_scope,
        nickname,
        initial_balance_cents,
        archived,
        institution_id,
        currency,
        created_at,
        updated_at
    ) values (
        v_user_id,
        p_type,
        v_scope,
        v_nickname,
        case when p_type = 'creditCard' then 0 else p_initial_balance_cents end,
        coalesce(p_archived, false),
        p_institution_id,
        v_currency,
        v_now,
        v_now
    )
    returning id into v_account_id;

    if p_type in ('checking', 'investment') then
        insert into app_private.bank_accounts (
            user_id,
            account_id,
            branch_id,
            account_number,
            bank_name,
            created_at,
            updated_at
        ) values (
            v_user_id,
            v_account_id,
            case when v_scope = 'brazilian' then v_branch_id else null end,
            v_account_number,
            case when v_scope = 'global' then v_bank_name else null end,
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
    p_territorial_scope text,
    p_nickname text,
    p_initial_balance_cents bigint,
    p_archived boolean,
    p_institution_id uuid,
    p_currency text,
    p_branch_id text default null,
    p_account_number text default null,
    p_bank_name text default null,
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
    v_scope text := nullif(trim(coalesce(p_territorial_scope, '')), '');
    v_nickname text := nullif(trim(coalesce(p_nickname, '')), '');
    v_currency text;
    v_branch_id text := nullif(trim(coalesce(p_branch_id, '')), '');
    v_account_number text := nullif(trim(coalesce(p_account_number, '')), '');
    v_bank_name text := nullif(trim(coalesce(p_bank_name, '')), '');
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

    if v_scope not in ('brazilian', 'global') then
        return jsonb_build_object('ok', false, 'code', 'invalid_territorial_scope');
    end if;

    v_currency := upper(trim(coalesce(p_currency, '')));
    if v_scope = 'brazilian' and v_currency = '' then
        v_currency := 'BRL';
    end if;

    if (v_scope = 'brazilian' and v_currency <> 'BRL')
        or (v_scope = 'global' and v_currency <> 'USD')
    then
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

    if p_type in ('checking', 'investment') then
        if v_account_number is null
            or (v_scope = 'global' and v_bank_name is null)
        then
            return jsonb_build_object('ok', false, 'code', 'invalid_account_identity');
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
        territorial_scope = v_scope,
        nickname = v_nickname,
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

    if p_type in ('checking', 'investment') then
        insert into app_private.bank_accounts (
            user_id,
            account_id,
            branch_id,
            account_number,
            bank_name,
            created_at,
            updated_at
        ) values (
            v_user_id,
            p_account_id,
            case when v_scope = 'brazilian' then v_branch_id else null end,
            v_account_number,
            case when v_scope = 'global' then v_bank_name else null end,
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

revoke all on function api.v1_list_accounts() from public;
revoke all on function api.v1_list_accounts() from anon;
revoke all on function api.v1_list_accounts() from authenticated;

revoke all on function api.v1_create_account(text, text, text, bigint, boolean, uuid, text, text, text, text, text, bigint, integer, integer) from public;
revoke all on function api.v1_create_account(text, text, text, bigint, boolean, uuid, text, text, text, text, text, bigint, integer, integer) from anon;
revoke all on function api.v1_create_account(text, text, text, bigint, boolean, uuid, text, text, text, text, text, bigint, integer, integer) from authenticated;

revoke all on function api.v1_update_account(uuid, text, text, text, bigint, boolean, uuid, text, text, text, text, text, bigint, integer, integer, timestamptz) from public;
revoke all on function api.v1_update_account(uuid, text, text, text, bigint, boolean, uuid, text, text, text, text, text, bigint, integer, integer, timestamptz) from anon;
revoke all on function api.v1_update_account(uuid, text, text, text, bigint, boolean, uuid, text, text, text, text, text, bigint, integer, integer, timestamptz) from authenticated;

grant execute on function api.v1_list_accounts() to authenticated;
grant execute on function api.v1_create_account(text, text, text, bigint, boolean, uuid, text, text, text, text, text, bigint, integer, integer) to authenticated;
grant execute on function api.v1_update_account(uuid, text, text, text, bigint, boolean, uuid, text, text, text, text, text, bigint, integer, integer, timestamptz) to authenticated;

revoke insert, update, delete on table app_private.accounts from authenticated;
revoke insert, update, delete on table app_private.bank_accounts from authenticated;
revoke insert, update, delete on table app_private.credit_cards from authenticated;
revoke insert, update, delete on table app_private.credit_card_cycle_configs from authenticated;
