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

create function api.v1_create_transaction(
    p_account_id uuid,
    p_category_id uuid,
    p_subcategory_id uuid,
    p_amount_cents bigint,
    p_occurred_at timestamptz,
    p_origin_occurred_at timestamptz default null,
    p_description text default null,
    p_notes text default null,
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

    if coalesce(length(trim(p_description)), 0) = 0 then
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
            description, notes, destination_account_id, created_at, updated_at
        ) values (
            v_user_id, p_account_id, p_category_id, p_subcategory_id, p_amount_cents,
            v_occurred_at, v_origin_occurred_at, p_purchase_type, p_installment_index, p_installment_count,
            trim(p_description), nullif(trim(coalesce(p_notes, '')), ''), p_destination_account_id, v_now, v_now
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

create function api.v1_update_transaction(
    p_transaction_id uuid,
    p_account_id uuid,
    p_category_id uuid,
    p_subcategory_id uuid,
    p_amount_cents bigint,
    p_occurred_at timestamptz,
    p_origin_occurred_at timestamptz default null,
    p_description text default null,
    p_notes text default null,
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
begin
    select t.id, t.account_id, t.destination_account_id
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

    if coalesce(length(trim(p_description)), 0) = 0 then
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
        t.statement_id
    into v_current
    from app_private.transactions t
    where t.user_id = v_user_id
      and t.id = p_transaction_id;

    if v_current.id is null then
        return jsonb_build_object('ok', false, 'code', 'transaction_not_found');
    end if;

    delete from app_private.statement_payments payment
    where payment.user_id = v_user_id
      and payment.transaction_id = p_transaction_id;

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
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) from public;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) from anon;
revoke all on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) from authenticated;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) from public;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) from anon;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) from authenticated;
revoke all on function api.v1_delete_transaction(uuid) from public;
revoke all on function api.v1_delete_transaction(uuid) from anon;
revoke all on function api.v1_delete_transaction(uuid) from authenticated;

grant execute on function api.v1_list_transactions(integer, timestamptz, timestamptz, uuid) to authenticated;
grant execute on function api.v1_create_transaction(uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) to authenticated;
grant execute on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) to authenticated;
grant execute on function api.v1_delete_transaction(uuid) to authenticated;
