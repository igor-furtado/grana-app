-- Ticket #17 rollback manual:
-- 1. revoke execute on function api.v1_ensure_profile() from authenticated;
-- 2. drop function if exists api.v1_ensure_profile();
-- 3. drop table if exists app_private.user_profiles;
-- 4. drop schema if exists api;
-- 5. drop schema if exists app_private;

create schema if not exists api;
create schema if not exists app_private;

revoke all on schema api from public;
revoke all on schema api from anon;
revoke all on schema api from authenticated;

revoke all on schema app_private from public;
revoke all on schema app_private from anon;
revoke all on schema app_private from authenticated;

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

alter table app_private.user_profiles enable row level security;

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
    on conflict (user_id) do update
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

grant usage on schema api to authenticated;
grant execute on function api.v1_ensure_profile() to authenticated;
