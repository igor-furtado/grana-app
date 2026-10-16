create index if not exists statement_payments_user_transaction_idx
    on app_private.statement_payments (
        user_id,
        transaction_id
    );

create or replace function api.v1_update_transaction(
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
    v_description text := trim(p_description);
    v_notes text := nullif(trim(coalesce(p_notes, '')), '');
    v_statement_id uuid;
begin
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
        t.destination_account_id,
        t.statement_id
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

    if coalesce(length(v_description), 0) = 0 then
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
       and v_account_type = 'creditCard'
    then
        v_occurred_at := app_private.v1_project_installment_competence(
            v_user_id,
            p_account_id,
            v_origin_occurred_at,
            p_installment_index
        );
    end if;

    begin
        if v_account_type = 'creditCard' and v_category_kind <> 'transfer' then
            v_statement_id := app_private.v1_find_or_create_statement_for_card_entry(
                v_user_id,
                p_account_id,
                v_occurred_at,
                v_now
            );
        end if;

        if v_current.account_id = p_account_id
           and v_current.category_id = p_category_id
           and v_current.subcategory_id is not distinct from p_subcategory_id
           and v_current.amount_cents = p_amount_cents
           and v_current.occurred_at = v_occurred_at
           and v_current.origin_occurred_at = v_origin_occurred_at
           and v_current.purchase_type is not distinct from p_purchase_type
           and v_current.installment_index is not distinct from p_installment_index
           and v_current.installment_count is not distinct from p_installment_count
           and v_current.description = v_description
           and v_current.notes is not distinct from v_notes
           and v_current.destination_account_id is not distinct from p_destination_account_id
           and v_current.statement_id is not distinct from v_statement_id
        then
            return jsonb_build_object('ok', true, 'code', null, 'transaction_id', p_transaction_id);
        end if;

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
            description = v_description,
            notes = v_notes,
            destination_account_id = p_destination_account_id,
            statement_id = v_statement_id,
            updated_at = v_now
        where user_id = v_user_id
          and id = p_transaction_id;

        delete from app_private.statement_payments payment
        where payment.user_id = v_user_id
          and payment.transaction_id = p_transaction_id;

        if p_destination_account_id is not null
           and v_destination_type = 'creditCard'
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

revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) from public;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) from anon;
revoke all on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) from authenticated;
grant execute on function api.v1_update_transaction(uuid, uuid, uuid, uuid, bigint, timestamptz, timestamptz, text, text, text, integer, integer, uuid) to authenticated;
