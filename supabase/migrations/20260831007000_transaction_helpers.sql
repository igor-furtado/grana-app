create or replace function app_private.v1_normalize_import_description(
    p_description text
)
returns text
language sql
immutable
security definer
set search_path = app_private, extensions
as $$
    select lower(trim(regexp_replace(coalesce(p_description, ''), '\s+', ' ', 'g')))
$$;

create or replace function app_private.v1_parse_inter_purchase_metadata(
    p_text text
)
returns table (
    purchase_type text,
    installment_index integer,
    installment_count integer
)
language plpgsql
immutable
security definer
set search_path = app_private, extensions
as $$
declare
    v_label text := nullif(trim(split_part(coalesce(p_text, ''), ' · ', 1)), '');
    v_match text[];
    v_normalized text;
begin
    if v_label is null then
        return;
    end if;

    v_normalized := lower(extensions.unaccent(v_label));

    if v_normalized = 'compra a vista' then
        purchase_type := 'cash';
        installment_index := null;
        installment_count := null;
        return next;
        return;
    end if;

    v_match := regexp_match(v_normalized, '^parcela ([0-9]+)/([0-9]+)$');
    if v_match is null then
        return;
    end if;

    purchase_type := 'installment';
    installment_index := v_match[1]::integer;
    installment_count := v_match[2]::integer;
    return next;
end;
$$;

create or replace function app_private.v1_build_inter_purchase_label(
    p_purchase_type text,
    p_installment_index integer,
    p_installment_count integer
)
returns text
language plpgsql
immutable
security definer
set search_path = app_private, extensions
as $$
begin
    if p_purchase_type = 'cash' then
        return 'Compra à vista';
    end if;

    if p_purchase_type = 'installment' then
        return format('Parcela %s/%s', p_installment_index, p_installment_count);
    end if;

    return null;
end;
$$;

create or replace function app_private.v1_rebuild_inter_import_notes(
    p_purchase_type text,
    p_installment_index integer,
    p_installment_count integer,
    p_original_notes text
)
returns text
language plpgsql
immutable
security definer
set search_path = app_private, extensions
as $$
declare
    v_suffix text := nullif(trim(substring(coalesce(p_original_notes, '') from ' · (.*)$')), '');
    v_label text := app_private.v1_build_inter_purchase_label(
        p_purchase_type,
        p_installment_index,
        p_installment_count
    );
begin
    if v_label is null then
        return nullif(trim(coalesce(p_original_notes, '')), '');
    end if;

    if v_suffix is null then
        return v_label;
    end if;

    return v_label || ' · ' || v_suffix;
end;
$$;

create or replace function app_private.v1_build_import_external_id(
    p_origin_occurred_at timestamptz,
    p_description text,
    p_amount_cents bigint,
    p_purchase_type text,
    p_installment_index integer,
    p_installment_count integer,
    p_fallback_external_id text default null
)
returns text
language plpgsql
immutable
security definer
set search_path = app_private, extensions
as $$
declare
    v_origin_day text;
    v_normalized_description text;
begin
    if p_purchase_type is null then
        return nullif(trim(coalesce(p_fallback_external_id, '')), '');
    end if;

    v_origin_day := to_char((p_origin_occurred_at at time zone 'UTC')::date, 'YYYY-MM-DD');
    v_normalized_description := app_private.v1_normalize_import_description(p_description);

    return format(
        'inter-cc:%s|%s|%s|%s|%s|%s',
        v_origin_day,
        v_normalized_description,
        p_amount_cents,
        p_purchase_type,
        coalesce(p_installment_index::text, '-'),
        coalesce(p_installment_count::text, '-')
    );
end;
$$;

create or replace function app_private.v1_resolve_card_cycle(
    p_user_id uuid,
    p_account_id uuid,
    p_reference_at timestamptz
)
returns table (
    statement_closing_day integer,
    payment_due_day integer
)
language plpgsql
stable
security definer
set search_path = app_private, extensions
as $$
begin
    return query
    select
        cycle.statement_closing_day,
        cycle.payment_due_day
    from app_private.credit_card_cycle_configs cycle
    where cycle.user_id = p_user_id
      and cycle.account_id = p_account_id
      and cycle.effective_from <= p_reference_at
    order by cycle.effective_from desc
    limit 1;

    if found then
        return;
    end if;

    return query
    select
        card.statement_closing_day,
        card.payment_due_day
    from app_private.credit_cards card
    where card.user_id = p_user_id
      and card.account_id = p_account_id
    limit 1;
end;
$$;

create or replace function app_private.v1_project_installment_competence(
    p_user_id uuid,
    p_account_id uuid,
    p_origin_occurred_at timestamptz,
    p_installment_index integer
)
returns timestamptz
language plpgsql
stable
security definer
set search_path = app_private, extensions
as $$
declare
    v_origin_local date := app_private.v1_local_date(p_user_id, p_origin_occurred_at);
    v_offset integer := greatest(coalesce(p_installment_index, 1) - 1, 0);
    v_cycle record;
    v_origin_window record;
    v_origin_closing_local date;
    v_target_closing_local date;
    v_target_previous_closing_local date;
    v_target_opening_local date;
    v_candidate_local date;
begin
    if p_installment_index is null or p_installment_index <= 1 then
        return app_private.v1_utc_midnight(v_origin_local);
    end if;

    select *
    into v_cycle
    from app_private.v1_resolve_card_cycle(p_user_id, p_account_id, p_origin_occurred_at);

    if v_cycle.statement_closing_day is null then
        raise exception using message = 'missing_cycle_configuration';
    end if;

    select *
    into v_origin_window
    from app_private.v1_resolve_statement_window(
        p_user_id,
        v_cycle.statement_closing_day,
        v_cycle.payment_due_day,
        p_origin_occurred_at
    );

    v_origin_closing_local := (v_origin_window.closing_date at time zone 'UTC')::date;
    v_target_closing_local := app_private.v1_make_month_day(
        extract(year from (v_origin_closing_local + make_interval(months => v_offset)))::integer,
        extract(month from (v_origin_closing_local + make_interval(months => v_offset)))::integer,
        v_cycle.statement_closing_day
    );
    v_target_previous_closing_local := app_private.v1_make_month_day(
        extract(year from (v_target_closing_local - interval '1 month'))::integer,
        extract(month from (v_target_closing_local - interval '1 month'))::integer,
        v_cycle.statement_closing_day
    );
    v_target_opening_local := v_target_previous_closing_local + 1;
    v_candidate_local := app_private.v1_make_month_day(
        extract(year from (v_origin_local + make_interval(months => v_offset)))::integer,
        extract(month from (v_origin_local + make_interval(months => v_offset)))::integer,
        extract(day from v_origin_local)::integer
    );

    if v_candidate_local < v_target_opening_local then
        v_candidate_local := v_target_opening_local;
    elsif v_candidate_local > v_target_closing_local then
        v_candidate_local := v_target_closing_local;
    end if;

    return app_private.v1_utc_midnight(v_candidate_local);
end;
$$;

create or replace function app_private.v1_import_commit_expand_rows(
    p_user_id uuid,
    p_account_id uuid,
    p_origin_occurred_at timestamptz,
    p_occurred_at timestamptz,
    p_purchase_type text,
    p_installment_index integer,
    p_installment_count integer,
    p_description text,
    p_notes text,
    p_external_id text,
    p_amount_cents bigint
)
returns table (
    occurred_at timestamptz,
    origin_occurred_at timestamptz,
    purchase_type text,
    installment_index integer,
    installment_count integer,
    notes text,
    external_id text
)
language sql
stable
security definer
set search_path = app_private, extensions
as $$
    with expanded as (
        select series.installment_index, p_installment_count as installment_count
        from generate_series(1, p_installment_count) as series(installment_index)
        where p_purchase_type = 'installment'
          and app_private.v1_is_credit_card_account(p_user_id, p_account_id)
        union all
        select p_installment_index, p_installment_count
        where not (
            p_purchase_type = 'installment'
            and app_private.v1_is_credit_card_account(p_user_id, p_account_id)
        )
    )
    select
        case
            when p_purchase_type = 'installment'
                 and app_private.v1_is_credit_card_account(p_user_id, p_account_id)
            then app_private.v1_project_installment_competence(
                p_user_id, p_account_id, p_origin_occurred_at, expanded.installment_index
            )
            else p_occurred_at
        end,
        p_origin_occurred_at,
        p_purchase_type,
        expanded.installment_index,
        expanded.installment_count,
        case
            when p_purchase_type = 'installment'
                 and app_private.v1_is_credit_card_account(p_user_id, p_account_id)
            then app_private.v1_rebuild_inter_import_notes(
                p_purchase_type, expanded.installment_index, expanded.installment_count, p_notes
            )
            else p_notes
        end,
        case
            when p_purchase_type is not null
            then app_private.v1_build_import_external_id(
                p_origin_occurred_at,
                p_description,
                p_amount_cents,
                p_purchase_type,
                expanded.installment_index,
                expanded.installment_count,
                p_external_id
            )
            else p_external_id
        end
    from expanded
$$;
