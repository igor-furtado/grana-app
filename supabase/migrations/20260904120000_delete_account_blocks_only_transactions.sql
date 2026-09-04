-- Rollback manual:
-- Reaplicar a versão anterior de api.v1_delete_account em
-- supabase/migrations/20260831004000_account_api.sql, restaurando os bloqueios
-- por app_private.statements e app_private.import_batches.
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
          and (
              t.account_id = p_account_id
              or t.destination_account_id = p_account_id
          )
    ) then
        return jsonb_build_object('ok', false, 'code', 'account_has_financial_history');
    end if;

    delete from app_private.accounts
    where user_id = v_user_id
      and id = p_account_id;

    return jsonb_build_object('ok', true, 'account_id', p_account_id);
end;
$$;
