-- Rollback manual:
-- 1. delete from app_private.supported_institutions_catalog where id = '948a28ad-3829-49e9-ab8a-d7d850239347';
-- 2. alter table app_private.supported_institutions_catalog
--        drop constraint if exists supported_institutions_catalog_kind_check;
-- 3. alter table app_private.supported_institutions_catalog
--        add constraint supported_institutions_catalog_kind_check
--        check (kind in ('inter', 'itau', 'bb', 'caixa', 'c6', 'xp', 'other'));

alter table app_private.supported_institutions_catalog
    drop constraint if exists supported_institutions_catalog_kind_check;

alter table app_private.supported_institutions_catalog
    add constraint supported_institutions_catalog_kind_check
    check (kind in ('inter', 'itau', 'nubank', 'bb', 'caixa', 'c6', 'xp', 'other'));

insert into app_private.supported_institutions_catalog (
    id,
    code,
    name,
    kind,
    supported_account_types,
    supported_import_formats,
    created_at,
    updated_at
) values (
    '948a28ad-3829-49e9-ab8a-d7d850239347',
    '260',
    'Nubank',
    'nubank',
    array['checking', 'creditCard']::text[],
    array['ofx']::text[],
    timezone('utc', now()),
    timezone('utc', now())
)
on conflict (id) do update set
    code = excluded.code,
    name = excluded.name,
    kind = excluded.kind,
    supported_account_types = excluded.supported_account_types,
    supported_import_formats = excluded.supported_import_formats,
    updated_at = timezone('utc', now());
