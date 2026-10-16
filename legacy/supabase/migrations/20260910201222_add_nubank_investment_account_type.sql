-- Rollback manual:
-- 1. update app_private.supported_institutions_catalog
--    set supported_account_types = array['checking', 'creditCard']::text[],
--        updated_at = timezone('utc', now())
--    where code = '260';

update app_private.supported_institutions_catalog
set supported_account_types = array['checking', 'creditCard', 'investment']::text[],
    updated_at = timezone('utc', now())
where code = '260';
