do $$
begin
    if not exists (
        select 1
        from pg_publication
        where pubname = 'powersync'
    ) then
        create publication powersync for table
            public.profiles,
            public.accounts,
            public.bank_accounts,
            public.credit_cards,
            public.credit_card_cycle_configs,
            public.statements,
            public.import_batches,
            public.transactions,
            public.statement_payments,
            public.statement_credit_applications,
            public.categorization_cache,
            public.categorization_corrections;
    end if;
end;
$$;
