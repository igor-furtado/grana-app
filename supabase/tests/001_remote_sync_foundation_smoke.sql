begin;

select plan(7);

select is(
    (select count(*)::integer
     from pg_class relation
     join pg_namespace namespace on namespace.oid = relation.relnamespace
     where namespace.nspname = 'public'
       and relation.relkind in ('r', 'v', 'm', 'f', 'p')
       and relation.relname in (
           'profiles',
           'accounts',
           'bank_accounts',
           'credit_cards',
           'transactions',
           'statements',
           'import_batches'
       )),
    0,
    'no product tables or views are created in public'
);

select ok(
    not has_table_privilege('authenticated', 'app_private.accounts', 'select'),
    'authenticated has no direct table access to private financial storage'
);

select ok(
    has_schema_privilege('service_role', 'api', 'usage'),
    'service role can reach api schema'
);

select ok(
    (select relrowsecurity
     from pg_class relation
     join pg_namespace namespace on namespace.oid = relation.relnamespace
     where namespace.nspname = 'app_private'
       and relation.relname = 'accounts'),
    'private account storage has RLS enabled'
);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values (
    '11111111-1111-1111-1111-111111111111',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'baseline@example.com',
    crypt('senha-segura', gen_salt('bf')),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    timezone('utc', now()),
    timezone('utc', now())
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

select lives_ok(
    'select * from api.v1_ensure_profile()',
    'authenticated user can bootstrap profile through api RPC'
);

reset role;

select is(
    (select count(*)::integer
     from app_private.user_profiles
     where user_id = '11111111-1111-1111-1111-111111111111'),
    1,
    'authenticated bootstrap creates private user profile'
);

select ok(
    exists (
        select 1
        from pg_constraint
        where conname = 'bank_accounts_user_id_account_id_fkey'
    ),
    'bank account storage keeps composite owner/account FK'
);

select * from finish();

rollback;
