alter role authenticator
set pgrst.db_timezone_enabled = 'false';

notify pgrst, 'reload config';

-- Rollback manual:
-- alter role authenticator reset pgrst.db_timezone_enabled;
-- notify pgrst, 'reload config';
