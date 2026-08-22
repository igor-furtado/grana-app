begin;

select plan(5);

select is(
    (select provider from app_private.ai_runtime_config limit 1),
    'openai',
    'global runtime config seeded with openai provider'
);

select is(
    (select model from app_private.ai_runtime_config limit 1),
    'gpt-5.4-mini',
    'global runtime config seeded with default model'
);

select ok(
    (select relrowsecurity
     from pg_class relation
     join pg_namespace namespace on namespace.oid = relation.relnamespace
     where namespace.nspname = 'app_private'
       and relation.relname = 'ai_user_overrides'),
    'AI user overrides have RLS enabled'
);

do $$
declare
    own_user uuid := gen_random_uuid();
begin
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (
        own_user,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'runtime-own@example.com',
        crypt('senha-segura', gen_salt('bf')),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{}'::jsonb,
        timezone('utc', now()),
        timezone('utc', now())
    );

    insert into app_private.user_profiles (user_id)
    values (own_user);

    insert into app_private.ai_user_overrides (user_id, provider, model)
    values (own_user, 'openai', 'gpt-test-model');
end
$$;

select is(
    (select model
     from api.v1_resolve_categorization_runtime_config(
         (select user_id from app_private.ai_user_overrides where model = 'gpt-test-model')
     )),
    'gpt-test-model',
    'runtime resolver applies per-user override through api RPC'
);

select ok(
    not has_table_privilege('authenticated', 'app_private.categorization_cache', 'select'),
    'authenticated has no direct cache table access'
);

select * from finish();

rollback;
