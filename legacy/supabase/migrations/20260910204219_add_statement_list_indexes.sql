create index if not exists statements_user_due_closing_created_id_idx
    on app_private.statements (
        user_id,
        due_date desc,
        closing_date desc,
        created_at desc,
        id desc
    );

create index if not exists transactions_user_statement_occurred_created_id_idx
    on app_private.transactions (
        user_id,
        statement_id,
        occurred_at desc,
        created_at desc,
        id desc
    )
    include (category_id, amount_cents)
    where statement_id is not null;

create index if not exists statement_payments_user_statement_created_idx
    on app_private.statement_payments (
        user_id,
        statement_id,
        created_at desc
    )
    include (applied_amount_cents);
