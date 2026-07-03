create schema if not exists private;

alter default privileges for role postgres in schema public
    revoke select, insert, update, delete on tables
    from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
    revoke usage, select on sequences
    from anon, authenticated, service_role;

create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, created_at, updated_at)
    values (
        new.id,
        coalesce(new.created_at, timezone('utc', now())),
        coalesce(new.updated_at, timezone('utc', now()))
    )
    on conflict (id) do update
    set updated_at = excluded.updated_at;

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function private.handle_new_auth_user();

create table if not exists public.accounts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    type text not null check (type in ('checking', 'creditCard')),
    initial_balance_cents bigint not null,
    archived boolean not null default false,
    institution_id uuid,
    currency text not null default 'BRL' check (char_length(currency) = 3),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id)
);

create table if not exists public.bank_accounts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    account_id uuid not null,
    branch_id text,
    account_number text not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    unique (user_id, account_id),
    foreign key (user_id, account_id)
        references public.accounts (user_id, id)
        on delete cascade
);

create table if not exists public.credit_cards (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
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
        references public.accounts (user_id, id)
        on delete cascade
);

create table if not exists public.credit_card_cycle_configs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    account_id uuid not null,
    effective_from timestamptz not null,
    statement_closing_day integer not null check (statement_closing_day between 1 and 31),
    payment_due_day integer not null check (payment_due_day between 1 and 31),
    created_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    unique (user_id, account_id, effective_from),
    foreign key (user_id, account_id)
        references public.credit_cards (user_id, account_id)
        on delete cascade
);

create table if not exists public.statements (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
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
        references public.accounts (user_id, id)
        on delete cascade
);

create table if not exists public.import_batches (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    source_filename text not null,
    account_id uuid not null,
    row_count integer not null check (row_count >= 0),
    imported_at timestamptz not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    foreign key (user_id, account_id)
        references public.accounts (user_id, id)
        on delete cascade
);

create table if not exists public.transactions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    account_id uuid not null,
    category_id uuid not null,
    subcategory_id uuid,
    amount_cents bigint not null check (amount_cents > 0),
    occurred_at timestamptz not null,
    description text not null check (length(trim(description)) > 0),
    notes text,
    import_batch_id uuid,
    external_id text,
    destination_account_id uuid,
    statement_id uuid,
    refund_of_transaction_id uuid,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    foreign key (user_id, account_id)
        references public.accounts (user_id, id)
        on delete cascade,
    foreign key (user_id, import_batch_id)
        references public.import_batches (user_id, id)
        on delete set null,
    foreign key (user_id, destination_account_id)
        references public.accounts (user_id, id)
        on delete set null,
    foreign key (user_id, statement_id)
        references public.statements (user_id, id)
        on delete set null,
    foreign key (user_id, refund_of_transaction_id)
        references public.transactions (user_id, id)
        on delete set null
);

create unique index if not exists transactions_user_account_external_id_idx
    on public.transactions (user_id, account_id, external_id)
    where external_id is not null;

create table if not exists public.statement_payments (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    statement_id uuid not null,
    transaction_id uuid not null,
    applied_amount_cents bigint not null check (applied_amount_cents > 0),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    foreign key (user_id, statement_id)
        references public.statements (user_id, id)
        on delete cascade,
    foreign key (user_id, transaction_id)
        references public.transactions (user_id, id)
        on delete cascade
);

create table if not exists public.statement_credit_applications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    source_statement_id uuid not null,
    destination_statement_id uuid not null,
    applied_amount_cents bigint not null check (applied_amount_cents > 0),
    created_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    foreign key (user_id, source_statement_id)
        references public.statements (user_id, id)
        on delete cascade,
    foreign key (user_id, destination_statement_id)
        references public.statements (user_id, id)
        on delete cascade
);

create table if not exists public.categorization_cache (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    description_hash text not null,
    normalized_description text not null,
    category_id uuid not null,
    subcategory_id uuid,
    confidence double precision not null check (confidence between 0 and 1),
    model text not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    unique (user_id, description_hash, model)
);

create table if not exists public.categorization_corrections (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    description_hash text not null,
    normalized_description text not null,
    original_category_id uuid,
    original_subcategory_id uuid,
    corrected_category_id uuid not null,
    corrected_subcategory_id uuid,
    transaction_id uuid not null,
    created_at timestamptz not null default timezone('utc', now()),
    unique (user_id, id),
    foreign key (user_id, transaction_id)
        references public.transactions (user_id, id)
        on delete cascade
);

do $$
declare
    table_name text;
begin
    foreach table_name in array ARRAY[
        'profiles',
        'accounts',
        'bank_accounts',
        'credit_cards',
        'credit_card_cycle_configs',
        'statements',
        'import_batches',
        'transactions',
        'statement_payments',
        'statement_credit_applications',
        'categorization_cache',
        'categorization_corrections'
    ]
    loop
        execute format(
            'grant select, insert, update, delete on table public.%I to authenticated',
            table_name
        );
        execute format(
            'grant select, insert, update, delete on table public.%I to service_role',
            table_name
        );
        execute format(
            'alter table public.%I enable row level security',
            table_name
        );
    end loop;
end;
$$;

drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_insert_own on public.profiles;
drop policy if exists profiles_update_own on public.profiles;
drop policy if exists profiles_delete_own on public.profiles;

create policy profiles_select_own
on public.profiles
for select
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = id);

create policy profiles_insert_own
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = id);

create policy profiles_update_own
on public.profiles
for update
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = id)
with check ((select auth.uid()) is not null and (select auth.uid()) = id);

create policy profiles_delete_own
on public.profiles
for delete
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = id);

do $$
declare
    table_name text;
    owner_tables text[] := array[
        'accounts',
        'bank_accounts',
        'credit_cards',
        'credit_card_cycle_configs',
        'statements',
        'import_batches',
        'transactions',
        'statement_payments',
        'statement_credit_applications',
        'categorization_cache',
        'categorization_corrections'
    ];
begin
    foreach table_name in array owner_tables
    loop
        execute format(
            'drop policy if exists %I on public.%I',
            table_name || '_select_own',
            table_name
        );
        execute format(
            'drop policy if exists %I on public.%I',
            table_name || '_insert_own',
            table_name
        );
        execute format(
            'drop policy if exists %I on public.%I',
            table_name || '_update_own',
            table_name
        );
        execute format(
            'drop policy if exists %I on public.%I',
            table_name || '_delete_own',
            table_name
        );

        execute format(
            'create policy %I on public.%I for select to authenticated using ((select auth.uid()) is not null and (select auth.uid()) = user_id)',
            table_name || '_select_own',
            table_name
        );
        execute format(
            'create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) is not null and (select auth.uid()) = user_id)',
            table_name || '_insert_own',
            table_name
        );
        execute format(
            'create policy %I on public.%I for update to authenticated using ((select auth.uid()) is not null and (select auth.uid()) = user_id) with check ((select auth.uid()) is not null and (select auth.uid()) = user_id)',
            table_name || '_update_own',
            table_name
        );
        execute format(
            'create policy %I on public.%I for delete to authenticated using ((select auth.uid()) is not null and (select auth.uid()) = user_id)',
            table_name || '_delete_own',
            table_name
        );
    end loop;
end;
$$;
