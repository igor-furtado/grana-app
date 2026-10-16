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
    select
        case
            when p_purchase_type = 'installment'
                 and app_private.v1_is_credit_card_account(p_user_id, p_account_id)
            then app_private.v1_project_installment_competence(
                p_user_id, p_account_id, p_origin_occurred_at, p_installment_index
            )
            else p_occurred_at
        end,
        p_origin_occurred_at,
        p_purchase_type,
        p_installment_index,
        p_installment_count,
        case
            when p_purchase_type = 'installment'
                 and app_private.v1_is_credit_card_account(p_user_id, p_account_id)
            then app_private.v1_rebuild_inter_import_notes(
                p_purchase_type, p_installment_index, p_installment_count, p_notes
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
                p_installment_index,
                p_installment_count,
                p_external_id
            )
            else p_external_id
        end
$$;

revoke all on function app_private.v1_import_commit_expand_rows(
    uuid,
    uuid,
    timestamptz,
    timestamptz,
    text,
    integer,
    integer,
    text,
    text,
    text,
    bigint
) from public;
revoke all on function app_private.v1_import_commit_expand_rows(
    uuid,
    uuid,
    timestamptz,
    timestamptz,
    text,
    integer,
    integer,
    text,
    text,
    text,
    bigint
) from anon;
revoke all on function app_private.v1_import_commit_expand_rows(
    uuid,
    uuid,
    timestamptz,
    timestamptz,
    text,
    integer,
    integer,
    text,
    text,
    text,
    bigint
) from authenticated;
