begin;

select plan(5);

select is(
    (select provider from private.ai_runtime_config limit 1),
    'openai',
    'global runtime config seeded with openai provider'
);

select is(
    (select model from private.ai_runtime_config limit 1),
    'gpt-5.4-mini',
    'global runtime config seeded with default model'
);

do $$
declare
    own_user uuid := gen_random_uuid();
    foreign_user uuid := gen_random_uuid();
begin
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values
        (own_user, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'runtime-own@example.com', crypt('senha-segura', gen_salt('bf')), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, timezone('utc', now()), timezone('utc', now())),
        (foreign_user, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'runtime-foreign@example.com', crypt('senha-segura', gen_salt('bf')), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, timezone('utc', now()), timezone('utc', now()));

    perform set_config('role', 'authenticated', true);
    perform set_config('request.jwt.claim.role', 'authenticated', true);
    perform set_config('request.jwt.claim.sub', own_user::text, true);

    insert into public.ai_user_overrides (user_id, provider, model)
    values (own_user, 'openai', 'gpt-5.4-mini');

    perform ok(
        exists(
            select 1
            from public.ai_user_overrides
            where user_id = own_user
        ),
        'authenticated user can insert own override'
    );

    perform ok(
        not exists(
            select 1
            from public.ai_user_overrides
            where user_id = foreign_user
        ),
        'authenticated user cannot see foreign override'
    );

    begin
        insert into public.ai_user_overrides (user_id, provider, model)
        values (foreign_user, 'openai', 'gpt-5.4-mini');
        perform fail('authenticated user should not insert foreign override');
    exception
        when others then
            perform pass('authenticated user cannot insert foreign override');
    end;
end
$$;

select * from finish();

rollback;
