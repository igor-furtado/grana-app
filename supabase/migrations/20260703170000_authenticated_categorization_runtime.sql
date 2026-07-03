create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;

create table if not exists private.ai_runtime_config (
    singleton boolean primary key default true check (singleton),
    provider text not null,
    model text not null,
    updated_at timestamptz not null default timezone('utc', now())
);

insert into private.ai_runtime_config (singleton, provider, model)
values (true, 'openai', 'gpt-5.4-mini')
on conflict (singleton) do nothing;

revoke all on all tables in schema private from public;
revoke all on all tables in schema private from anon;
revoke all on all tables in schema private from authenticated;

create table if not exists public.ai_user_overrides (
    user_id uuid primary key references public.profiles (id) on delete cascade,
    provider text not null,
    model text not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

alter table public.ai_user_overrides enable row level security;

grant select, insert, update, delete on public.ai_user_overrides to authenticated;
grant select, insert, update, delete on public.ai_user_overrides to service_role;

drop policy if exists "ai_user_overrides_select_own" on public.ai_user_overrides;
create policy "ai_user_overrides_select_own"
on public.ai_user_overrides
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "ai_user_overrides_insert_own" on public.ai_user_overrides;
create policy "ai_user_overrides_insert_own"
on public.ai_user_overrides
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "ai_user_overrides_update_own" on public.ai_user_overrides;
create policy "ai_user_overrides_update_own"
on public.ai_user_overrides
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "ai_user_overrides_delete_own" on public.ai_user_overrides;
create policy "ai_user_overrides_delete_own"
on public.ai_user_overrides
for delete
to authenticated
using (user_id = auth.uid());

create or replace function public.resolve_categorization_runtime_config(target_user_id uuid)
returns table (
    provider text,
    model text
)
language sql
security definer
set search_path = public, private
as $$
    select
        coalesce(user_override.provider, global_config.provider) as provider,
        coalesce(user_override.model, global_config.model) as model
    from private.ai_runtime_config as global_config
    left join public.ai_user_overrides as user_override
        on user_override.user_id = target_user_id
    limit 1
$$;

revoke all on function public.resolve_categorization_runtime_config(uuid) from public;
revoke all on function public.resolve_categorization_runtime_config(uuid) from anon;
revoke all on function public.resolve_categorization_runtime_config(uuid) from authenticated;
grant execute on function public.resolve_categorization_runtime_config(uuid) to service_role;
