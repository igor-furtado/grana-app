create index if not exists transactions_user_occurred_created_id_idx
    on app_private.transactions (
        user_id,
        occurred_at desc,
        created_at desc,
        id desc
    );
