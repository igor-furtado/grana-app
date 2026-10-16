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

revoke all on function api.v1_delete_transaction(uuid) from public;
revoke all on function api.v1_delete_transaction(uuid) from anon;
revoke all on function api.v1_delete_transaction(uuid) from authenticated;

grant execute on function api.v1_delete_transaction(uuid) to authenticated;
