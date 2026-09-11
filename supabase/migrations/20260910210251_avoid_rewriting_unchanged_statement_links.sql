create or replace function app_private.v1_rebuild_card_statements(
    p_user_id uuid,
    p_account_id uuid,
    p_reference_date timestamptz default timezone('utc', now())
)
returns void
language plpgsql
security definer
set search_path = app_private, extensions
as $$
declare
    v_now timestamptz := timezone('utc', now());
    v_entry record;
    v_statement_id uuid;
begin
    if not app_private.v1_is_credit_card_account(p_user_id, p_account_id) then
        return;
    end if;

    drop table if exists pg_temp.statement_tx_map;
    create temporary table pg_temp.statement_tx_map (
        transaction_id uuid primary key,
        statement_id uuid not null
    ) on commit drop;

    for v_entry in
        select
            card_entry.id,
            card_entry.occurred_at
        from app_private.transactions card_entry
        join app_private.category_catalog category
            on category.id = card_entry.category_id
        where card_entry.user_id = p_user_id
          and card_entry.account_id = p_account_id
          and category.kind <> 'transfer'
        order by card_entry.occurred_at asc, card_entry.id asc
    loop
        v_statement_id := app_private.v1_find_or_create_statement_for_card_entry(
            p_user_id,
            p_account_id,
            v_entry.occurred_at,
            p_reference_date
        );

        insert into pg_temp.statement_tx_map (
            transaction_id,
            statement_id
        ) values (
            v_entry.id,
            v_statement_id
        )
        on conflict (transaction_id) do update
        set statement_id = excluded.statement_id;
    end loop;

    update app_private.transactions txn
    set
        statement_id = tx_map.statement_id,
        updated_at = v_now
    from pg_temp.statement_tx_map tx_map
    where txn.user_id = p_user_id
      and txn.id = tx_map.transaction_id
      and txn.statement_id is distinct from tx_map.statement_id;

    update app_private.transactions txn
    set
        statement_id = null,
        updated_at = v_now
    where txn.user_id = p_user_id
      and txn.account_id = p_account_id
      and txn.statement_id is not null
      and not exists (
          select 1
          from pg_temp.statement_tx_map tx_map
          where tx_map.transaction_id = txn.id
      );

end;
$$;
