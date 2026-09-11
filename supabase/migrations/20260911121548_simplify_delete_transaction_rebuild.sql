create index if not exists statement_payments_user_transaction_idx
    on app_private.statement_payments (
        user_id,
        transaction_id
    );

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

    return jsonb_build_object(
        'ok', true,
        'code', null,
        'transaction_id', p_transaction_id
    );
end;
$$;
