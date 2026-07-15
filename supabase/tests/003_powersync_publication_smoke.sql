-- Smoke tests for issue #14.
-- Execute against a non-production Supabase project after the migrations.

begin;

select exists (
    select 1
    from pg_publication
    where pubname = 'powersync'
) as powersync_publication_exists;

select (
    select puballtables
    from pg_publication
    where pubname = 'powersync'
) = true
or (
    select count(distinct rel.relname) = 12
    from pg_publication pub
    join pg_publication_rel pub_rel on pub_rel.prpubid = pub.oid
    join pg_class rel on rel.oid = pub_rel.prrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where pub.pubname = 'powersync'
      and nsp.nspname = 'public'
      and rel.relname in (
        'profiles',
        'accounts',
        'bank_accounts',
        'credit_cards',
        'credit_card_cycle_configs',
        'statements',
        'import_batches',
        'transactions',
        'statement_payments',
        'statement_credit_applications',
        'categorization_cache',
        'categorization_corrections'
      )
) as publication_covers_synced_tables;

rollback;
