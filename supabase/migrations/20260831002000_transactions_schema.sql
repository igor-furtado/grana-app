alter table app_private.transactions
    add constraint transactions_category_id_fkey
    foreign key (category_id)
    references app_private.category_catalog (id)
    on delete restrict;

alter table app_private.transactions
    add constraint transactions_subcategory_id_fkey
    foreign key (subcategory_id)
    references app_private.category_catalog (id)
    on delete restrict;
