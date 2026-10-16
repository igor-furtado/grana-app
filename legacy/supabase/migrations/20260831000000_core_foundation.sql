-- Baseline Supabase online-only:
-- - no product objects in public
-- - private storage in app_private
-- - versioned app surface in api

create schema if not exists api;
create schema if not exists app_private;

revoke all on schema api from public;
revoke all on schema api from anon;
revoke all on schema api from authenticated;

revoke all on schema app_private from public;
revoke all on schema app_private from anon;
revoke all on schema app_private from authenticated;

grant usage on schema api to authenticated, service_role;

alter default privileges for role postgres in schema api
    revoke all on tables from public, anon, authenticated;

alter default privileges for role postgres in schema api
    revoke all on functions from public, anon, authenticated;

alter default privileges for role postgres in schema app_private
    revoke all on tables from public, anon, authenticated;

alter default privileges for role postgres in schema app_private
    revoke all on functions from public, anon, authenticated;

create table if not exists app_private.user_profiles (
    user_id uuid primary key references auth.users (id) on delete cascade,
    default_currency text not null default 'BRL' check (char_length(default_currency) = 3),
    timezone text not null default 'UTC',
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists app_private.accounts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_private.user_profiles (user_id) on delete cascade,
    type text not null check (type in ('checking', 'creditCard')),
    initial_balance_cents bigint not null,
    archived boolean not null default false,
    institution_id uuid,
    currency text not null default 'BRL' check (char_length(currency) = 3),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id)
);

create table if not exists app_private.bank_accounts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_private.user_profiles (user_id) on delete cascade,
    account_id uuid not null,
    branch_id text,
    account_number text not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    unique (user_id, account_id),
    foreign key (user_id, account_id)
        references app_private.accounts (user_id, id)
        on delete cascade
);

create table if not exists app_private.credit_cards (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_private.user_profiles (user_id) on delete cascade,
    account_id uuid not null,
    card_last_four text not null check (card_last_four ~ '^[0-9]{4}$'),
    credit_limit_cents bigint check (credit_limit_cents is null or credit_limit_cents >= 0),
    statement_closing_day integer not null check (statement_closing_day between 1 and 31),
    payment_due_day integer not null check (payment_due_day between 1 and 31),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    unique (user_id, account_id),
    foreign key (user_id, account_id)
        references app_private.accounts (user_id, id)
        on delete cascade
);

create table if not exists app_private.credit_card_cycle_configs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_private.user_profiles (user_id) on delete cascade,
    account_id uuid not null,
    effective_from timestamptz not null,
    statement_closing_day integer not null check (statement_closing_day between 1 and 31),
    payment_due_day integer not null check (payment_due_day between 1 and 31),
    created_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    unique (user_id, account_id, effective_from),
    foreign key (user_id, account_id)
        references app_private.credit_cards (user_id, account_id)
        on delete cascade
);

create table if not exists app_private.statements (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_private.user_profiles (user_id) on delete cascade,
    account_id uuid not null,
    closing_date timestamptz not null,
    due_date timestamptz not null,
    net_amount_cents bigint not null,
    credit_received_cents bigint not null default 0 check (credit_received_cents >= 0),
    payment_applied_cents bigint not null default 0 check (payment_applied_cents >= 0),
    settled_at timestamptz,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    unique (user_id, account_id, closing_date),
    foreign key (user_id, account_id)
        references app_private.accounts (user_id, id)
        on delete cascade
);

create table if not exists app_private.import_batches (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_private.user_profiles (user_id) on delete cascade,
    source_filename text not null,
    account_id uuid not null,
    row_count integer not null check (row_count >= 0),
    imported_at timestamptz not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    foreign key (user_id, account_id)
        references app_private.accounts (user_id, id)
        on delete cascade
);

create table if not exists app_private.transactions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_private.user_profiles (user_id) on delete cascade,
    account_id uuid not null,
    category_id uuid not null,
    subcategory_id uuid,
    amount_cents bigint not null check (amount_cents > 0),
    occurred_at timestamptz not null,
    origin_occurred_at timestamptz not null,
    purchase_type text,
    installment_index integer,
    installment_count integer,
    description text not null check (length(trim(description)) > 0),
    notes text,
    import_batch_id uuid,
    external_id text,
    destination_account_id uuid,
    statement_id uuid,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    foreign key (user_id, account_id)
        references app_private.accounts (user_id, id)
        on delete cascade,
    foreign key (user_id, import_batch_id)
        references app_private.import_batches (user_id, id)
        on delete set null,
    foreign key (user_id, destination_account_id)
        references app_private.accounts (user_id, id)
        on delete set null,
    foreign key (user_id, statement_id)
        references app_private.statements (user_id, id)
        on delete set null,
    constraint transactions_purchase_shape_check
    check (
        (
            purchase_type is null
            and installment_index is null
            and installment_count is null
        )
        or (
            purchase_type = 'cash'
            and installment_index is null
            and installment_count is null
        )
        or (
            purchase_type = 'installment'
            and installment_index is not null
            and installment_count is not null
            and installment_index >= 1
            and installment_count >= 2
            and installment_index <= installment_count
        )
    )
);

create unique index if not exists transactions_user_account_external_id_idx
    on app_private.transactions (user_id, account_id, external_id)
    where external_id is not null;

create table if not exists app_private.statement_payments (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_private.user_profiles (user_id) on delete cascade,
    statement_id uuid not null,
    transaction_id uuid not null,
    applied_amount_cents bigint not null check (applied_amount_cents > 0),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    foreign key (user_id, statement_id)
        references app_private.statements (user_id, id)
        on delete cascade,
    foreign key (user_id, transaction_id)
        references app_private.transactions (user_id, id)
        on delete cascade
);

do $$
declare
    table_name text;
begin
    foreach table_name in array ARRAY[
        'user_profiles',
        'accounts',
        'bank_accounts',
        'credit_cards',
        'credit_card_cycle_configs',
        'statements',
        'import_batches',
        'transactions',
        'statement_payments'
    ]
    loop
        execute format('alter table app_private.%I enable row level security', table_name);
    end loop;
end;
$$;

create policy user_profiles_select_own
on app_private.user_profiles
for select
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy user_profiles_insert_own
on app_private.user_profiles
for insert
to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy user_profiles_update_own
on app_private.user_profiles
for update
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id)
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

do $$
declare
    table_name text;
begin
    foreach table_name in array ARRAY[
        'accounts',
        'bank_accounts',
        'credit_cards',
        'credit_card_cycle_configs',
        'statements',
        'import_batches',
        'transactions',
        'statement_payments'
    ]
    loop
        execute format(
            'create policy %I on app_private.%I for select to authenticated using ((select auth.uid()) is not null and (select auth.uid()) = user_id)',
            table_name || '_select_own',
            table_name
        );
        execute format(
            'create policy %I on app_private.%I for insert to authenticated with check ((select auth.uid()) is not null and (select auth.uid()) = user_id)',
            table_name || '_insert_own',
            table_name
        );
        execute format(
            'create policy %I on app_private.%I for update to authenticated using ((select auth.uid()) is not null and (select auth.uid()) = user_id) with check ((select auth.uid()) is not null and (select auth.uid()) = user_id)',
            table_name || '_update_own',
            table_name
        );
        execute format(
            'create policy %I on app_private.%I for delete to authenticated using ((select auth.uid()) is not null and (select auth.uid()) = user_id)',
            table_name || '_delete_own',
            table_name
        );
    end loop;
end;
$$;
