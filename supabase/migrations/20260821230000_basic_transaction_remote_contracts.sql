-- Ticket #20 rollback manual:
-- 1. grant insert, update, delete on table public.transactions to authenticated;
-- 2. revoke execute on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) from authenticated;
-- 3. revoke execute on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from authenticated;
-- 4. revoke execute on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from authenticated;
-- 5. revoke execute on function api.v1_delete_transaction(uuid) from authenticated;
-- 6. drop function if exists api.v1_list_transactions(integer, timestamptz, timestamptz, uuid);
-- 7. drop function if exists api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid);
-- 8. drop function if exists api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid);
-- 9. drop function if exists api.v1_delete_transaction(uuid);

create or replace function api.v1_list_transactions(
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
    refund_of_transaction_id uuid,
    created_at timestamptz,
    updated_at timestamptz
)
language sql
security invoker
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
        t.refund_of_transaction_id,
        t.created_at,
        t.updated_at
    from public.transactions t
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
    p_description text,
    p_notes text,
    p_destination_account_id uuid,
    p_refund_of_transaction_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, app_private, extensions
as $$
declare
    v_user_id uuid := auth.uid();
    v_transaction_id uuid;
    v_account_type text;
    v_destination_type text;
    v_category_kind text;
begin
    select a.type
    into v_account_type
    from public.accounts a
    where a.user_id = v_user_id
      and a.id = p_account_id;

    if v_account_type is null then
        return jsonb_build_object('ok', false, 'code', 'invalid_account');
    end if;

    if v_account_type = 'creditCard' then
        return jsonb_build_object('ok', false, 'code', 'credit_card_transactions_not_supported');
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

    if p_refund_of_transaction_id is not null then
        return jsonb_build_object('ok', false, 'code', 'refunds_not_supported');
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
        from public.accounts a
        where a.user_id = v_user_id
          and a.id = p_destination_account_id;

        if v_destination_type is null then
            return jsonb_build_object('ok', false, 'code', 'invalid_transfer_destination');
        end if;

        if v_destination_type = 'creditCard' then
            return jsonb_build_object('ok', false, 'code', 'credit_card_transactions_not_supported');
        end if;
    end if;

    insert into public.transactions (
        user_id,
        account_id,
        category_id,
        subcategory_id,
        amount_cents,
        occurred_at,
        description,
        notes,
        destination_account_id,
        refund_of_transaction_id
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
        null
    )
    returning id into v_transaction_id;

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
set search_path = public, app_private, extensions
as $$
declare
    v_user_id uuid := auth.uid();
    v_current record;
    v_account_type text;
    v_destination_type text;
    v_category_kind text;
begin
    select
        t.id,
        t.account_id,
        t.destination_account_id,
        t.statement_id,
        t.refund_of_transaction_id
    into v_current
    from public.transactions t
    where t.user_id = v_user_id
      and t.id = p_transaction_id;

    if v_current.id is null then
        return jsonb_build_object('ok', false, 'code', 'transaction_not_found');
    end if;

    if v_current.statement_id is not null
       or v_current.refund_of_transaction_id is not null
    then
        return jsonb_build_object('ok', false, 'code', 'credit_card_transactions_not_supported');
    end if;

    if exists (
        select 1
        from public.transactions linked
        where linked.user_id = v_user_id
          and linked.refund_of_transaction_id = p_transaction_id
    ) then
        return jsonb_build_object('ok', false, 'code', 'linked_refunds_exist');
    end if;

    select a.type
    into v_account_type
    from public.accounts a
    where a.user_id = v_user_id
      and a.id = p_account_id;

    if v_account_type is null then
        return jsonb_build_object('ok', false, 'code', 'invalid_account');
    end if;

    if v_account_type = 'creditCard' then
        return jsonb_build_object('ok', false, 'code', 'credit_card_transactions_not_supported');
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

    if p_refund_of_transaction_id is not null then
        return jsonb_build_object('ok', false, 'code', 'refunds_not_supported');
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
        from public.accounts a
        where a.user_id = v_user_id
          and a.id = p_destination_account_id;

        if v_destination_type is null then
            return jsonb_build_object('ok', false, 'code', 'invalid_transfer_destination');
        end if;

        if v_destination_type = 'creditCard' then
            return jsonb_build_object('ok', false, 'code', 'credit_card_transactions_not_supported');
        end if;
    end if;

    update public.transactions
    set
        account_id = p_account_id,
        category_id = p_category_id,
        subcategory_id = p_subcategory_id,
        amount_cents = p_amount_cents,
        occurred_at = p_occurred_at,
        description = trim(p_description),
        notes = nullif(trim(coalesce(p_notes, '')), ''),
        destination_account_id = p_destination_account_id,
        refund_of_transaction_id = null,
        updated_at = timezone('utc', now())
    where user_id = v_user_id
      and id = p_transaction_id;

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
set search_path = public, app_private, extensions
as $$
declare
    v_user_id uuid := auth.uid();
    v_current record;
begin
    select
        t.id,
        destination.type as destination_account_type,
        t.statement_id,
        t.refund_of_transaction_id
    into v_current
    from public.transactions t
    left join public.accounts destination
        on destination.user_id = v_user_id
       and destination.id = t.destination_account_id
    where t.user_id = v_user_id
      and t.id = p_transaction_id;

    if v_current.id is null then
        return jsonb_build_object('ok', false, 'code', 'transaction_not_found');
    end if;

    if exists (
        select 1
        from public.transactions linked
        where linked.user_id = v_user_id
          and linked.refund_of_transaction_id = p_transaction_id
    ) then
        return jsonb_build_object('ok', false, 'code', 'linked_refunds_exist');
    end if;

    if v_current.statement_id is not null
       or v_current.destination_account_type = 'creditCard'
       or v_current.refund_of_transaction_id is not null
    then
        return jsonb_build_object('ok', false, 'code', 'credit_card_transactions_not_supported');
    end if;

    delete from public.transactions
    where user_id = v_user_id
      and id = p_transaction_id;

    return jsonb_build_object(
        'ok', true,
        'code', null,
        'transaction_id', p_transaction_id
    );
end;
$$;

revoke all on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) from public;
revoke all on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) from anon;
revoke all on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) from authenticated;

revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from public;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from anon;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from authenticated;

revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from public;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from anon;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) from authenticated;

revoke all on function api.v1_delete_transaction(uuid) from public;
revoke all on function api.v1_delete_transaction(uuid) from anon;
revoke all on function api.v1_delete_transaction(uuid) from authenticated;

grant execute on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) to authenticated;
grant execute on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) to authenticated;
grant execute on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, text, text, uuid, uuid) to authenticated;
grant execute on function api.v1_delete_transaction(uuid) to authenticated;

revoke insert, update, delete on table public.transactions from authenticated;
