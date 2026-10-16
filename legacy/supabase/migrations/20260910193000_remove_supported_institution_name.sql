-- Rollback manual:
-- 1. alter table app_private.supported_institutions_catalog add column name text;
-- 2. update app_private.supported_institutions_catalog
--    set name = case kind
--        when 'inter' then 'Banco Inter'
--        when 'itau' then 'Itaú'
--        when 'nubank' then 'Nubank'
--        when 'bb' then 'Banco do Brasil'
--        when 'caixa' then 'Caixa Econômica Federal'
--        when 'c6' then 'C6 Bank'
--        when 'xp' then 'XP Investimentos'
--        else 'Outro'
--    end;
-- 3. alter table app_private.supported_institutions_catalog alter column name set not null;
-- 4. drop view if exists api.v1_supported_institution_catalog;
-- 5. create view api.v1_supported_institution_catalog as
--    select id, code, name, kind, supported_account_types, supported_import_formats, created_at, updated_at
--    from app_private.supported_institutions_catalog;
-- 6. grant select on table api.v1_supported_institution_catalog to authenticated;

drop view if exists api.v1_supported_institution_catalog;

alter table app_private.supported_institutions_catalog
    drop column if exists name;

create view api.v1_supported_institution_catalog as
select
    id,
    code,
    kind,
    supported_account_types,
    supported_import_formats,
    created_at,
    updated_at
from app_private.supported_institutions_catalog;

revoke all on table api.v1_supported_institution_catalog from public;
revoke all on table api.v1_supported_institution_catalog from anon;
revoke all on table api.v1_supported_institution_catalog from authenticated;

grant select on table api.v1_supported_institution_catalog to authenticated;
