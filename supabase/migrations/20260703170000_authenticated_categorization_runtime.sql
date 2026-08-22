create table if not exists app_private.ai_runtime_config (
    singleton boolean primary key default true check (singleton),
    provider text not null,
    model text not null,
    updated_at timestamptz not null default timezone('utc', now())
);

insert into app_private.ai_runtime_config (singleton, provider, model)
values (true, 'openai', 'gpt-5.4-mini')
on conflict (singleton) do nothing;

create table if not exists app_private.ai_user_overrides (
    user_id uuid primary key references app_private.user_profiles (user_id) on delete cascade,
    provider text not null,
    model text not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

alter table app_private.ai_runtime_config enable row level security;
alter table app_private.ai_user_overrides enable row level security;

create policy ai_user_overrides_select_own
on app_private.ai_user_overrides
for select
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy ai_user_overrides_insert_own
on app_private.ai_user_overrides
for insert
to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy ai_user_overrides_update_own
on app_private.ai_user_overrides
for update
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id)
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy ai_user_overrides_delete_own
on app_private.ai_user_overrides
for delete
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create or replace function api.v1_resolve_categorization_runtime_config(target_user_id uuid)
returns table (
    provider text,
    model text
)
language sql
security definer
set search_path = ''
as $$
    select
        coalesce(user_override.provider, global_config.provider) as provider,
        coalesce(user_override.model, global_config.model) as model
    from app_private.ai_runtime_config as global_config
    left join app_private.ai_user_overrides as user_override
        on user_override.user_id = target_user_id
    limit 1
$$;

create or replace function api.v1_lookup_categorization_cache(
    p_description_hashes text[],
    p_model text
)
returns table (
    description_hash text,
    category_id uuid,
    subcategory_id uuid,
    confidence double precision
)
language sql
security definer
set search_path = ''
as $$
    select
        cache.description_hash,
        cache.category_id,
        cache.subcategory_id,
        cache.confidence
    from app_private.categorization_cache cache
    where cache.user_id = auth.uid()
      and cache.model = p_model
      and cache.description_hash = any(p_description_hashes)
$$;

create or replace function api.v1_list_categorization_few_shots(
    p_limit integer default 10
)
returns table (
    normalized_description text,
    corrected_category_id uuid,
    corrected_subcategory_id uuid
)
language sql
security definer
set search_path = ''
as $$
    select
        correction.normalized_description,
        correction.corrected_category_id,
        correction.corrected_subcategory_id
    from app_private.categorization_corrections correction
    where correction.user_id = auth.uid()
    order by correction.created_at desc
    limit greatest(1, least(coalesce(p_limit, 10), 50))
$$;

revoke all on function api.v1_resolve_categorization_runtime_config(uuid) from public;
revoke all on function api.v1_resolve_categorization_runtime_config(uuid) from anon;
revoke all on function api.v1_resolve_categorization_runtime_config(uuid) from authenticated;
grant execute on function api.v1_resolve_categorization_runtime_config(uuid) to service_role;

revoke all on function api.v1_lookup_categorization_cache(text[], text) from public;
revoke all on function api.v1_lookup_categorization_cache(text[], text) from anon;
revoke all on function api.v1_lookup_categorization_cache(text[], text) from authenticated;
grant execute on function api.v1_lookup_categorization_cache(text[], text) to authenticated;

revoke all on function api.v1_list_categorization_few_shots(integer) from public;
revoke all on function api.v1_list_categorization_few_shots(integer) from anon;
revoke all on function api.v1_list_categorization_few_shots(integer) from authenticated;
grant execute on function api.v1_list_categorization_few_shots(integer) to authenticated;
