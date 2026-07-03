-- Smoke tests for issue #10.
-- Execute against a non-production Supabase project after the migration.

begin;

-- The trigger should anchor a minimal profile row for each authenticated user.
insert into auth.users (id, email, created_at, updated_at)
values
    ('11111111-1111-1111-1111-111111111111', 'user1@example.com', timezone('utc', now()), timezone('utc', now())),
    ('22222222-2222-2222-2222-222222222222', 'user2@example.com', timezone('utc', now()), timezone('utc', now()));

select count(*) = 2 as profiles_created
from public.profiles
where id in (
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);

insert into public.accounts (
    id,
    user_id,
    type,
    initial_balance_cents,
    archived,
    institution_id,
    currency,
    created_at,
    updated_at
)
values (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111111',
    'checking',
    0,
    false,
    '33333333-3333-3333-3333-333333333333',
    'BRL',
    timezone('utc', now()),
    timezone('utc', now())
);

select count(*) = 1 as own_account_visible
from public.accounts;

-- Expect 0 rows because RLS should hide another user's rows.
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);

select count(*) = 0 as foreign_account_hidden
from public.accounts
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

reset role;

-- Composite FK between bank_accounts and accounts must exist.
select exists (
    select 1
    from pg_constraint
    where conname = 'bank_accounts_user_id_account_id_fkey'
) as bank_account_fk_present;

-- Local catalogs remain local in this phase: no server FK to categories/institutions.
select count(*) = 0 as no_server_fk_to_local_catalogs
from pg_constraint
where contype = 'f'
  and (
    pg_get_constraintdef(oid) ilike '%categories%'
    or pg_get_constraintdef(oid) ilike '%institutions%'
  );

rollback;
