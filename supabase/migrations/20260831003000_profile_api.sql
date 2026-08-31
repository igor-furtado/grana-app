create or replace function api.v1_ensure_profile()
returns table (
    user_id uuid,
    default_currency text,
    timezone text,
    created_at timestamptz,
    updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    target_user_id uuid := auth.uid();
begin
    if target_user_id is null then
        raise exception using
            errcode = '42501',
            message = 'Authentication required';
    end if;

    return query
    insert into app_private.user_profiles as profile (
        user_id,
        default_currency,
        timezone
    )
    values (
        target_user_id,
        'BRL',
        'UTC'
    )
    on conflict on constraint user_profiles_pkey do update
    set updated_at = profile.updated_at
    returning
        profile.user_id,
        profile.default_currency,
        profile.timezone,
        profile.created_at,
        profile.updated_at;
end;
$$;

revoke all on function api.v1_ensure_profile() from public;
revoke all on function api.v1_ensure_profile() from anon;
revoke all on function api.v1_ensure_profile() from authenticated;
grant execute on function api.v1_ensure_profile() to authenticated;
