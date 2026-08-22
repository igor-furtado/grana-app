-- Ticket #18 rollback manual:
-- 1. revoke select on api.v1_supported_institution_catalog from authenticated;
-- 2. revoke select on api.v1_category_catalog from authenticated;
-- 3. drop view if exists api.v1_supported_institution_catalog;
-- 4. drop view if exists api.v1_category_catalog;
-- 5. drop table if exists app_private.supported_institutions_catalog;
-- 6. drop table if exists app_private.category_catalog;

create table if not exists app_private.category_catalog (
    id uuid primary key,
    parent_id uuid references app_private.category_catalog (id) on delete restrict,
    slug text,
    name text not null,
    kind text not null check (kind in ('expense', 'income', 'transfer')),
    created_at timestamptz not null default timezone('utc', now()),
    constraint category_catalog_root_slug_shape check (
        (parent_id is null and slug is not null)
        or (parent_id is not null and slug is null)
    )
);

create unique index if not exists category_catalog_root_slug_key
    on app_private.category_catalog (slug)
    where parent_id is null;

create unique index if not exists category_catalog_subcategory_name_key
    on app_private.category_catalog (parent_id, name)
    where parent_id is not null;

create table if not exists app_private.supported_institutions_catalog (
    id uuid primary key,
    code text not null unique,
    name text not null,
    kind text not null check (kind in ('inter', 'itau', 'bb', 'caixa', 'c6', 'xp', 'other')),
    supported_account_types text[] not null check (cardinality(supported_account_types) > 0),
    supported_import_formats text[] not null default '{}'::text[],
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

alter table app_private.accounts
    add constraint accounts_institution_id_fkey
    foreign key (institution_id)
    references app_private.supported_institutions_catalog (id)
    on delete restrict;

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

alter table app_private.categorization_cache
    add constraint categorization_cache_category_id_fkey
    foreign key (category_id)
    references app_private.category_catalog (id)
    on delete restrict;

alter table app_private.categorization_cache
    add constraint categorization_cache_subcategory_id_fkey
    foreign key (subcategory_id)
    references app_private.category_catalog (id)
    on delete restrict;

alter table app_private.categorization_corrections
    add constraint categorization_corrections_original_category_id_fkey
    foreign key (original_category_id)
    references app_private.category_catalog (id)
    on delete restrict;

alter table app_private.categorization_corrections
    add constraint categorization_corrections_original_subcategory_id_fkey
    foreign key (original_subcategory_id)
    references app_private.category_catalog (id)
    on delete restrict;

alter table app_private.categorization_corrections
    add constraint categorization_corrections_corrected_category_id_fkey
    foreign key (corrected_category_id)
    references app_private.category_catalog (id)
    on delete restrict;

alter table app_private.categorization_corrections
    add constraint categorization_corrections_corrected_subcategory_id_fkey
    foreign key (corrected_subcategory_id)
    references app_private.category_catalog (id)
    on delete restrict;

create or replace view api.v1_category_catalog as
select
    id,
    parent_id,
    slug,
    name,
    kind,
    created_at
from app_private.category_catalog;

create or replace view api.v1_supported_institution_catalog as
select
    id,
    code,
    name,
    kind,
    supported_account_types,
    supported_import_formats,
    created_at,
    updated_at
from app_private.supported_institutions_catalog;

revoke all on table api.v1_category_catalog from public;
revoke all on table api.v1_category_catalog from anon;
revoke all on table api.v1_category_catalog from authenticated;

revoke all on table api.v1_supported_institution_catalog from public;
revoke all on table api.v1_supported_institution_catalog from anon;
revoke all on table api.v1_supported_institution_catalog from authenticated;

grant usage on schema api to authenticated;
grant select on table api.v1_category_catalog to authenticated;
grant select on table api.v1_supported_institution_catalog to authenticated;

insert into app_private.category_catalog (id, parent_id, slug, name, kind, created_at) values
    ('9681063f-9489-839c-b960-102c5330724f', null, 'renda-e-pagamentos', 'Renda e Pagamentos', 'income', timezone('utc', now())),
    ('898ed341-4275-886d-b037-309cec86fc67', '9681063f-9489-839c-b960-102c5330724f', null, 'Salário', 'income', timezone('utc', now())),
    ('7e975550-fdee-8633-a047-8e8c8c2c2761', '9681063f-9489-839c-b960-102c5330724f', null, 'Freelance', 'income', timezone('utc', now())),
    ('0d1215a9-11e1-8300-b4ca-df7666379b8f', '9681063f-9489-839c-b960-102c5330724f', null, '13º Salário', 'income', timezone('utc', now())),
    ('a2878639-fbb9-8fe1-914f-9b87391b62b3', '9681063f-9489-839c-b960-102c5330724f', null, 'Férias', 'income', timezone('utc', now())),
    ('563314c9-ae63-8ba4-978a-d9b42b1cc45e', '9681063f-9489-839c-b960-102c5330724f', null, 'PLR', 'income', timezone('utc', now())),
    ('784dec13-c048-8630-8f9a-d65eb1a69011', '9681063f-9489-839c-b960-102c5330724f', null, 'Juros de Investimentos', 'income', timezone('utc', now())),
    ('e0d95209-ec2b-8d3a-a6b0-fb4ebd5b08b5', '9681063f-9489-839c-b960-102c5330724f', null, 'Dividendos', 'income', timezone('utc', now())),
    ('59652d2f-74bb-8f96-96a5-9cb08208c09a', '9681063f-9489-839c-b960-102c5330724f', null, 'Restituição de IR', 'income', timezone('utc', now())),
    ('429ce711-2178-8f2c-be08-927570d25edd', '9681063f-9489-839c-b960-102c5330724f', null, 'Cashback', 'income', timezone('utc', now())),
    ('63aecaee-4a78-85d0-8e2b-192156bd0b70', '9681063f-9489-839c-b960-102c5330724f', null, 'Reembolso', 'income', timezone('utc', now())),
    ('c1ad33bd-bc49-8542-adc9-b98fb62541f1', null, 'compras', 'Compras', 'expense', timezone('utc', now())),
    ('d709458a-5d74-8e0d-80d1-850749f0463f', 'c1ad33bd-bc49-8542-adc9-b98fb62541f1', null, 'Roupas e Calçados', 'expense', timezone('utc', now())),
    ('c6ef5b04-0229-83a4-9d84-a684f93e7224', 'c1ad33bd-bc49-8542-adc9-b98fb62541f1', null, 'Acessórios e Joias', 'expense', timezone('utc', now())),
    ('ee78358b-16be-817c-b189-4942e6a7cad2', 'c1ad33bd-bc49-8542-adc9-b98fb62541f1', null, 'Presentes', 'expense', timezone('utc', now())),
    ('6bb51b4c-31d7-8807-b304-15c1855365e9', 'c1ad33bd-bc49-8542-adc9-b98fb62541f1', null, 'Artigos Esportivos', 'expense', timezone('utc', now())),
    ('61919c13-1621-8fd4-b199-58b98ab14e0b', 'c1ad33bd-bc49-8542-adc9-b98fb62541f1', null, 'Hobbies e Coleções', 'expense', timezone('utc', now())),
    ('67305ae8-e06c-8b14-9ff7-626fbe913e3f', null, 'cuidados-pessoais', 'Cuidados Pessoais', 'expense', timezone('utc', now())),
    ('d06007c7-c19f-8453-accc-71f31cd57b37', '67305ae8-e06c-8b14-9ff7-626fbe913e3f', null, 'Barbearia', 'expense', timezone('utc', now())),
    ('e946eea1-0982-8a25-9377-f4340a2a394a', '67305ae8-e06c-8b14-9ff7-626fbe913e3f', null, 'Massagem', 'expense', timezone('utc', now())),
    ('73f22c9d-be29-8056-a8eb-a5b310210285', '67305ae8-e06c-8b14-9ff7-626fbe913e3f', null, 'Cosméticos e Higiene', 'expense', timezone('utc', now())),
    ('8d09295c-d3f7-8aa1-aaec-4faeb999e8a1', null, 'mobilidade', 'Mobilidade', 'expense', timezone('utc', now())),
    ('6b250eec-1607-8fb3-868a-387f430284a3', '8d09295c-d3f7-8aa1-aaec-4faeb999e8a1', null, 'Uber e 99', 'expense', timezone('utc', now())),
    ('43b51249-fefd-8d31-a36b-f3b86671ffed', '8d09295c-d3f7-8aa1-aaec-4faeb999e8a1', null, 'Táxi', 'expense', timezone('utc', now())),
    ('c77b7211-e669-89d6-a503-f1f8204b30a9', '8d09295c-d3f7-8aa1-aaec-4faeb999e8a1', null, 'Transporte Público', 'expense', timezone('utc', now())),
    ('a4df6e62-353c-85e9-a9a4-9b8c791ecc24', '8d09295c-d3f7-8aa1-aaec-4faeb999e8a1', null, 'Pedágio', 'expense', timezone('utc', now())),
    ('4570b662-2d23-82c4-a78d-802e076ea0c6', null, 'moto', 'Moto', 'expense', timezone('utc', now())),
    ('42baa6a1-4364-8df9-8111-fc2738309ab5', '4570b662-2d23-82c4-a78d-802e076ea0c6', null, 'Combustível', 'expense', timezone('utc', now())),
    ('bc130ac3-22a7-882f-908c-9b0e7f839d67', '4570b662-2d23-82c4-a78d-802e076ea0c6', null, 'Manutenção e Mecânica', 'expense', timezone('utc', now())),
    ('f6edd030-16da-8bd5-aeec-e67515096e4e', '4570b662-2d23-82c4-a78d-802e076ea0c6', null, 'Estacionamento', 'expense', timezone('utc', now())),
    ('30fb351d-11d3-8878-97d2-83c38984e2f5', '4570b662-2d23-82c4-a78d-802e076ea0c6', null, 'Licenciamento', 'expense', timezone('utc', now())),
    ('2e1b43de-c6e9-8fb5-ac0c-47032bc93bca', '4570b662-2d23-82c4-a78d-802e076ea0c6', null, 'Multas de Trânsito', 'expense', timezone('utc', now())),
    ('95ddc2a6-d064-8464-bb84-a71dc16ef7c4', '4570b662-2d23-82c4-a78d-802e076ea0c6', null, 'Seguro Moto', 'expense', timezone('utc', now())),
    ('e5b26406-4064-8595-b962-83a70bfe3a23', '4570b662-2d23-82c4-a78d-802e076ea0c6', null, 'Equipamentos e Acessórios', 'expense', timezone('utc', now())),
    ('d7c79302-c10e-8e2e-b7a8-11742f2fcc4c', null, 'viagem', 'Viagem', 'expense', timezone('utc', now())),
    ('c347e3c1-9020-8502-95cd-53a81e80cd7f', 'd7c79302-c10e-8e2e-b7a8-11742f2fcc4c', null, 'Passagens Aéreas', 'expense', timezone('utc', now())),
    ('724aa0d9-093f-82fc-a05d-e899fbd66fac', 'd7c79302-c10e-8e2e-b7a8-11742f2fcc4c', null, 'Hospedagem', 'expense', timezone('utc', now())),
    ('9eb64ca9-ff6b-8304-9ef1-22acfb100aed', 'd7c79302-c10e-8e2e-b7a8-11742f2fcc4c', null, 'Pacotes de Viagem', 'expense', timezone('utc', now())),
    ('5757bab9-ba5b-8447-b6c4-7da21047a24b', 'd7c79302-c10e-8e2e-b7a8-11742f2fcc4c', null, 'Bagagem', 'expense', timezone('utc', now())),
    ('8d89008b-c193-8150-a113-dad902e84f74', 'd7c79302-c10e-8e2e-b7a8-11742f2fcc4c', null, 'Seguro Viagem', 'expense', timezone('utc', now())),
    ('84594dd0-dd0d-8064-b6ef-c82fccbf02ff', 'd7c79302-c10e-8e2e-b7a8-11742f2fcc4c', null, 'Passeios e Atrações', 'expense', timezone('utc', now())),
    ('8c512a0b-e975-8697-8c6b-c6b9c3359125', 'd7c79302-c10e-8e2e-b7a8-11742f2fcc4c', null, 'Câmbio', 'expense', timezone('utc', now())),
    ('41e6aa0c-67aa-8645-b439-c24c24eb08d4', null, 'entretenimento', 'Entretenimento', 'expense', timezone('utc', now())),
    ('5663218f-9ad5-841b-81d0-3d1401d2a742', '41e6aa0c-67aa-8645-b439-c24c24eb08d4', null, 'Cinema', 'expense', timezone('utc', now())),
    ('e717110c-e318-808a-a2a3-942c7494600d', '41e6aa0c-67aa-8645-b439-c24c24eb08d4', null, 'Teatro', 'expense', timezone('utc', now())),
    ('19f6b71c-0866-8df7-977b-cd21eae0b923', '41e6aa0c-67aa-8645-b439-c24c24eb08d4', null, 'Parques e Diversões', 'expense', timezone('utc', now())),
    ('59e8ea1c-722f-8e10-af87-f38cabbc226e', '41e6aa0c-67aa-8645-b439-c24c24eb08d4', null, 'Loterias', 'expense', timezone('utc', now())),
    ('5c6597bf-2459-8deb-a6e8-2dff86f9fe98', null, 'festas', 'Festas', 'expense', timezone('utc', now())),
    ('a917a356-965b-893f-a066-e0adc49b69a7', '5c6597bf-2459-8deb-a6e8-2dff86f9fe98', null, 'Bares', 'expense', timezone('utc', now())),
    ('166bd854-6dfa-8534-b6be-295ed8f1d9ea', '5c6597bf-2459-8deb-a6e8-2dff86f9fe98', null, 'Baladas e Boates', 'expense', timezone('utc', now())),
    ('6760732b-a733-8106-bcaa-13022a6c25ac', '5c6597bf-2459-8deb-a6e8-2dff86f9fe98', null, 'Festas e Eventos', 'expense', timezone('utc', now())),
    ('978adbf4-4370-8216-9117-31bd76bbd628', '5c6597bf-2459-8deb-a6e8-2dff86f9fe98', null, 'Shows e Festivais', 'expense', timezone('utc', now())),
    ('967f9e68-41d0-83c7-ba0d-ce9cae8f85fb', null, 'danca', 'Dança', 'expense', timezone('utc', now())),
    ('5ba474d5-36f8-892e-9195-5929598ac682', '967f9e68-41d0-83c7-ba0d-ce9cae8f85fb', null, 'Escola de Dança', 'expense', timezone('utc', now())),
    ('bfd73df4-16b4-8de9-a0ba-996d9fedd0f8', '967f9e68-41d0-83c7-ba0d-ce9cae8f85fb', null, 'Bailes', 'expense', timezone('utc', now())),
    ('6ae5e8e6-9b5c-871d-a254-1bfa5804c1d8', '967f9e68-41d0-83c7-ba0d-ce9cae8f85fb', null, 'Workshops', 'expense', timezone('utc', now())),
    ('1622bae0-f92b-85f2-9ba4-54b35d0ef73d', '967f9e68-41d0-83c7-ba0d-ce9cae8f85fb', null, 'Congressos', 'expense', timezone('utc', now())),
    ('a4d4cea5-9f50-8e69-9d05-9cb21244cf7a', null, 'trabalho', 'Trabalho', 'expense', timezone('utc', now())),
    ('b71c00a9-dafd-85c7-b236-58cb13542888', 'a4d4cea5-9f50-8e69-9d05-9cb21244cf7a', null, 'Hardware', 'expense', timezone('utc', now())),
    ('b41a466b-49ad-8c81-865b-6e7480329be7', 'a4d4cea5-9f50-8e69-9d05-9cb21244cf7a', null, 'Conferências e Eventos Tech', 'expense', timezone('utc', now())),
    ('a27c02ea-7bd7-8d50-99fa-c41a318f05a2', null, 'educacao', 'Educação', 'expense', timezone('utc', now())),
    ('009dfccf-e977-8b14-811f-aa56d039213a', 'a27c02ea-7bd7-8d50-99fa-c41a318f05a2', null, 'Mensalidades', 'expense', timezone('utc', now())),
    ('fa331bd8-57b2-8309-a92e-e94d4256e54c', 'a27c02ea-7bd7-8d50-99fa-c41a318f05a2', null, 'Cursos', 'expense', timezone('utc', now())),
    ('9d5ba6ba-28d4-86c8-a903-49d8c298f3d6', 'a27c02ea-7bd7-8d50-99fa-c41a318f05a2', null, 'Certificações', 'expense', timezone('utc', now())),
    ('54558004-6756-812f-a300-08d4d100d9e5', 'a27c02ea-7bd7-8d50-99fa-c41a318f05a2', null, 'Livros', 'expense', timezone('utc', now())),
    ('a0525d52-2fd6-8e7b-aded-eb7008900912', 'a27c02ea-7bd7-8d50-99fa-c41a318f05a2', null, 'Material Escolar', 'expense', timezone('utc', now())),
    ('e10c92d0-8441-8a3f-8ca7-a89f061b1bf7', null, 'alimentacao', 'Alimentação', 'expense', timezone('utc', now())),
    ('8c1a5ee3-2cff-84a0-bc1e-ac1968786814', 'e10c92d0-8441-8a3f-8ca7-a89f061b1bf7', null, 'Supermercados', 'expense', timezone('utc', now())),
    ('9629fa5f-389b-80cb-99ea-ea260d907088', 'e10c92d0-8441-8a3f-8ca7-a89f061b1bf7', null, 'Mercearias', 'expense', timezone('utc', now())),
    ('14352abb-8dad-809c-85c9-dbf44634e2bd', 'e10c92d0-8441-8a3f-8ca7-a89f061b1bf7', null, 'Açougues', 'expense', timezone('utc', now())),
    ('f79f403d-4deb-8ccd-ac50-683591c9f092', 'e10c92d0-8441-8a3f-8ca7-a89f061b1bf7', null, 'Padarias', 'expense', timezone('utc', now())),
    ('33b6c716-6e38-8995-99f9-eeda23677add', 'e10c92d0-8441-8a3f-8ca7-a89f061b1bf7', null, 'Restaurantes', 'expense', timezone('utc', now())),
    ('37ca8e4f-9571-8093-9dec-ccd2a5eb7e4a', 'e10c92d0-8441-8a3f-8ca7-a89f061b1bf7', null, 'Lanchonetes', 'expense', timezone('utc', now())),
    ('100d9f91-74a1-82d7-91ad-4843d9b46d00', 'e10c92d0-8441-8a3f-8ca7-a89f061b1bf7', null, 'Delivery de Comida', 'expense', timezone('utc', now())),
    ('3e2a0b52-7aa4-8a60-ab7d-c6bd066fdc9d', 'e10c92d0-8441-8a3f-8ca7-a89f061b1bf7', null, 'Cafeterias', 'expense', timezone('utc', now())),
    ('c0a21329-17c0-8996-bd07-d4da68878e33', 'e10c92d0-8441-8a3f-8ca7-a89f061b1bf7', null, 'Feira e Hortifrúti', 'expense', timezone('utc', now())),
    ('4253d5d8-73fb-8bee-bd53-418a08170917', null, 'moradia', 'Moradia', 'expense', timezone('utc', now())),
    ('f567caa3-6dfd-8e4c-bb28-e9cb72159675', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Aluguel', 'expense', timezone('utc', now())),
    ('246f5824-2f9e-81c1-a106-d521d9d989d2', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Entrada e Encargos', 'expense', timezone('utc', now())),
    ('3737637b-3727-8b62-a391-787278893986', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Condomínio', 'expense', timezone('utc', now())),
    ('5dba01bf-cffd-8060-8df2-bffe2972499b', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Energia Elétrica', 'expense', timezone('utc', now())),
    ('904e4bdf-b3b6-8929-a541-9444f44f2dca', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Água', 'expense', timezone('utc', now())),
    ('ec9412b2-486d-8570-a8df-4b07ae949b5d', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Gás', 'expense', timezone('utc', now())),
    ('ea45e71d-da8e-8966-98c6-6b1de61bdbc7', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'IPTU', 'expense', timezone('utc', now())),
    ('0fc2543c-c697-8d76-8544-a5f725fc51b1', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Financiamento Imobiliário', 'expense', timezone('utc', now())),
    ('64bc183f-3b94-8bc7-8e89-67e364b2ecd9', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Reforma', 'expense', timezone('utc', now())),
    ('9572d066-368d-8c7c-80aa-b818bc5171a1', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Móveis', 'expense', timezone('utc', now())),
    ('6713dbbc-673a-8804-aa18-726ea0132f14', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Decoração', 'expense', timezone('utc', now())),
    ('0bb98458-be92-8e8b-b6f9-d60d60f96e84', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Eletrônicos', 'expense', timezone('utc', now())),
    ('090d7ab3-8a00-8fa5-ba81-51c65255cd75', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Utensílios Domésticos', 'expense', timezone('utc', now())),
    ('8c4fc7a7-3291-8704-8072-136d1dc3dc3f', '4253d5d8-73fb-8bee-bd53-418a08170917', null, 'Ferramentas', 'expense', timezone('utc', now())),
    ('9ef69e97-0e28-8dc7-b30e-bf8943b636ec', null, 'streaming-e-apps', 'Streaming e Apps', 'expense', timezone('utc', now())),
    ('e40b887d-4efd-88b5-8c6b-0b0368b012d4', '9ef69e97-0e28-8dc7-b30e-bf8943b636ec', null, 'Streaming de Vídeo', 'expense', timezone('utc', now())),
    ('e193d3fb-f59c-80f3-af2c-6cea7bb5fe01', '9ef69e97-0e28-8dc7-b30e-bf8943b636ec', null, 'Streaming de Música', 'expense', timezone('utc', now())),
    ('45b17f27-3203-8f72-b6e4-86af9098a1ef', '9ef69e97-0e28-8dc7-b30e-bf8943b636ec', null, 'IA e Produtividade', 'expense', timezone('utc', now())),
    ('c6b7f95b-b9b1-8851-b819-8ef4d64ffa67', '9ef69e97-0e28-8dc7-b30e-bf8943b636ec', null, 'Apps e Softwares', 'expense', timezone('utc', now())),
    ('42f27239-6654-8a20-bb22-711fb9ed1bd2', '9ef69e97-0e28-8dc7-b30e-bf8943b636ec', null, 'Jogos', 'expense', timezone('utc', now())),
    ('5cc83ca8-b35d-8f22-a958-ffcdc463b69e', null, 'conectividade', 'Conectividade', 'expense', timezone('utc', now())),
    ('5c1cfdd2-c78e-89ae-8fd8-3d075890775d', '5cc83ca8-b35d-8f22-a958-ffcdc463b69e', null, 'Internet Banda Larga', 'expense', timezone('utc', now())),
    ('de7ef89e-0853-8e89-8659-73e661da8134', '5cc83ca8-b35d-8f22-a958-ffcdc463b69e', null, 'Celular', 'expense', timezone('utc', now())),
    ('30d572eb-8469-8acd-8f8d-eb60ed282e81', null, 'exercicios', 'Exercícios', 'expense', timezone('utc', now())),
    ('49615d02-c074-8976-8a6c-7af293c9eade', '30d572eb-8469-8acd-8f8d-eb60ed282e81', null, 'Academia', 'expense', timezone('utc', now())),
    ('63d11ecc-8724-851a-b701-7cb0d1e0503c', '30d572eb-8469-8acd-8f8d-eb60ed282e81', null, 'Personal Trainer', 'expense', timezone('utc', now())),
    ('4996416e-003f-8f3d-935a-51bd073105a2', '30d572eb-8469-8acd-8f8d-eb60ed282e81', null, 'Crossfit', 'expense', timezone('utc', now())),
    ('86dcb4c6-a8f6-8665-b141-bc740787fc41', '30d572eb-8469-8acd-8f8d-eb60ed282e81', null, 'Pilates', 'expense', timezone('utc', now())),
    ('bf08883d-e041-807f-a8dd-4e4f5a11ec06', null, 'servicos-profissionais', 'Serviços Profissionais', 'expense', timezone('utc', now())),
    ('a6a73711-2bba-8aa7-a18f-388f04678685', 'bf08883d-e041-807f-a8dd-4e4f5a11ec06', null, 'Contabilidade', 'expense', timezone('utc', now())),
    ('cc2751cc-f9f5-8195-ac48-60cb576d49c6', 'bf08883d-e041-807f-a8dd-4e4f5a11ec06', null, 'Jurídico e Advocacia', 'expense', timezone('utc', now())),
    ('eb3fcc0d-0aec-82d1-b3de-c8a5976072bb', 'bf08883d-e041-807f-a8dd-4e4f5a11ec06', null, 'Consultoria', 'expense', timezone('utc', now())),
    ('c12eacaa-aed9-8d0f-8b46-764aa2514236', 'bf08883d-e041-807f-a8dd-4e4f5a11ec06', null, 'Limpeza Doméstica', 'expense', timezone('utc', now())),
    ('add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'saude', 'Saúde', 'expense', timezone('utc', now())),
    ('07ba5c9c-0182-8b17-b38c-191e58439827', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Plano de Saúde', 'expense', timezone('utc', now())),
    ('2a89485e-6f6d-80ff-baf6-0f292b26d176', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Consultas Médicas', 'expense', timezone('utc', now())),
    ('f8a80f62-fd86-8fbb-adbc-e50047dd15c2', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Consultas Dentárias', 'expense', timezone('utc', now())),
    ('93d41ba9-47c2-866c-933a-d3a646389b7a', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Nutricionista', 'expense', timezone('utc', now())),
    ('3aec2716-acfd-87d2-8bac-628d36069ef8', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Psicoterapia', 'expense', timezone('utc', now())),
    ('3bdf3e55-1d18-89e6-8fd3-be04aa2832b1', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Fisioterapia', 'expense', timezone('utc', now())),
    ('46781b10-f02e-84c5-a2de-41c986a72d04', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Farmácias e Medicamentos', 'expense', timezone('utc', now())),
    ('874b4728-852b-8623-b7bc-91b5231a4840', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Exames', 'expense', timezone('utc', now())),
    ('59f103a0-2c4b-8bf5-8f5f-e2ae974c5e44', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Vacinas', 'expense', timezone('utc', now())),
    ('8f23dafe-2baa-82ec-b60b-648d5cb1c847', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Cirurgias', 'expense', timezone('utc', now())),
    ('4e0ccba2-485d-8bc5-ad9a-92e7735104a5', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Emergências Médicas', 'expense', timezone('utc', now())),
    ('990a6247-7a0a-854f-b861-de38e84d1b24', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Óculos e Lentes', 'expense', timezone('utc', now())),
    ('42789ce2-9527-8db8-9090-356adc0a6e55', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Aparelhos Ortodônticos', 'expense', timezone('utc', now())),
    ('d6e233ab-d6dd-8ee6-bfb9-5378ca34efe1', 'add52642-8eb5-83ce-8a4c-9cd71245fb89', null, 'Suplementos', 'expense', timezone('utc', now())),
    ('16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'investimentos', 'Investimentos', 'expense', timezone('utc', now())),
    ('ab024773-6c27-8144-be29-c7f135622e9f', '16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'Poupança', 'expense', timezone('utc', now())),
    ('971f31ae-ad41-8236-a299-93b691e7acfa', '16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'CDB', 'expense', timezone('utc', now())),
    ('655bd052-ba9b-89dd-8d39-d51f90de7136', '16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'Tesouro Direto', 'expense', timezone('utc', now())),
    ('6257fc8e-a981-8333-b17f-6eaf08e54bc3', '16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'LCI/LCA', 'expense', timezone('utc', now())),
    ('b9bbdea8-5c31-8209-a18d-7c61bdbc000b', '16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'Fundos de Investimento', 'expense', timezone('utc', now())),
    ('7dd25025-6222-8b0b-b157-dc0977e0d27f', '16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'Ações Bolsa', 'expense', timezone('utc', now())),
    ('c43fb627-dd88-8daf-9595-46421b82d7da', '16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'FIIs', 'expense', timezone('utc', now())),
    ('a5041583-161c-8d0f-be18-2f05ab748128', '16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'ETFs', 'expense', timezone('utc', now())),
    ('963dc950-be21-8cac-8db5-10918d670ac5', '16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'Previdência Privada', 'expense', timezone('utc', now())),
    ('136b2081-1a82-847e-b46f-1ebd98addee5', '16ebb3ec-254f-8453-b0a2-a4461ec58a5c', null, 'Criptomoedas', 'expense', timezone('utc', now())),
    ('2e7a1051-0064-84c6-8323-7e65e5cacd22', null, 'impostos', 'Impostos', 'expense', timezone('utc', now())),
    ('8fe828ff-0806-875c-9870-df670deb7a10', '2e7a1051-0064-84c6-8323-7e65e5cacd22', null, 'Imposto de Renda', 'expense', timezone('utc', now())),
    ('ccfd6b6b-7a4a-805d-a0ec-b005c737d7bf', '2e7a1051-0064-84c6-8323-7e65e5cacd22', null, 'DAS', 'expense', timezone('utc', now())),
    ('3346cc4b-cb90-88c0-ae0f-812f757ef349', '2e7a1051-0064-84c6-8323-7e65e5cacd22', null, 'INSS Autônomo', 'expense', timezone('utc', now())),
    ('356e38b3-7153-8490-ba08-f86c7ff2bcb3', '2e7a1051-0064-84c6-8323-7e65e5cacd22', null, 'ISS', 'expense', timezone('utc', now())),
    ('06866fc2-c10e-8b42-8581-01d41c3af73b', '2e7a1051-0064-84c6-8323-7e65e5cacd22', null, 'ITBI', 'expense', timezone('utc', now())),
    ('a85a7f35-aa38-88e3-b3f3-1844ad66df16', '2e7a1051-0064-84c6-8323-7e65e5cacd22', null, 'Taxas Cartoriais', 'expense', timezone('utc', now())),
    ('4db1529d-c8c8-8c7c-adb5-fac474d4d0b4', '2e7a1051-0064-84c6-8323-7e65e5cacd22', null, 'Taxas Bancárias', 'expense', timezone('utc', now())),
    ('81c572b1-888d-8259-9308-795fcd3db8b8', '2e7a1051-0064-84c6-8323-7e65e5cacd22', null, 'IOF', 'expense', timezone('utc', now())),
    ('9bd718c0-954f-8583-95f3-fb51e229648a', null, 'saques', 'Saques', 'expense', timezone('utc', now())),
    ('aad133cd-a1a0-868d-b43e-5890f2183815', '9bd718c0-954f-8583-95f3-fb51e229648a', null, 'Saque em Agência', 'expense', timezone('utc', now())),
    ('16dc3b8c-8246-86c0-8702-dab3e79bdaa9', '9bd718c0-954f-8583-95f3-fb51e229648a', null, 'Taxa de Saque', 'expense', timezone('utc', now())),
    ('cdf816bb-8aa7-80d0-96f5-d8f06d619c7e', null, 'nao-classificado', 'Não Classificado', 'expense', timezone('utc', now())),
    ('92fe441a-7b11-8f0d-ab36-d3634ca3adba', 'cdf816bb-8aa7-80d0-96f5-d8f06d619c7e', null, 'Pendente de Revisão', 'expense', timezone('utc', now())),
    ('55321ad1-ba4d-8e90-ad38-43997b1aa475', null, 'transferencias', 'Transferências', 'transfer', timezone('utc', now())),
    ('7b0b486c-cb3e-8095-a0ee-a5de799a7ba8', '55321ad1-ba4d-8e90-ad38-43997b1aa475', null, 'PIX Enviado', 'transfer', timezone('utc', now())),
    ('a666b156-7009-8d46-a923-aacb5d153ea3', '55321ad1-ba4d-8e90-ad38-43997b1aa475', null, 'PIX Recebido', 'transfer', timezone('utc', now())),
    ('cfc68df1-19c5-866c-82cc-b5cd0fd6053c', '55321ad1-ba4d-8e90-ad38-43997b1aa475', null, 'TED Enviada', 'transfer', timezone('utc', now())),
    ('708f7966-ee4e-869c-aaf4-baa80446c9e8', '55321ad1-ba4d-8e90-ad38-43997b1aa475', null, 'TED Recebida', 'transfer', timezone('utc', now())),
    ('b4b12045-dfad-837d-a737-18bdb81247ac', '55321ad1-ba4d-8e90-ad38-43997b1aa475', null, 'Transferência entre Contas', 'transfer', timezone('utc', now())),
    ('a8b02afb-c55c-860e-9790-36e2b07d9f07', '55321ad1-ba4d-8e90-ad38-43997b1aa475', null, 'Transferência Internacional', 'transfer', timezone('utc', now())),
    ('71b2b49a-8515-8064-b31a-d8b73ac2eb6b', '55321ad1-ba4d-8e90-ad38-43997b1aa475', null, 'Depósito em Conta', 'transfer', timezone('utc', now()))
on conflict (id) do update set
    parent_id = excluded.parent_id,
    slug = excluded.slug,
    name = excluded.name,
    kind = excluded.kind;

insert into app_private.supported_institutions_catalog (id, code, name, kind, supported_account_types, supported_import_formats, created_at, updated_at) values
    ('9809e12a-e489-8d3e-8992-eb8eac61df7b', '001', 'Banco do Brasil', 'bb', array['checking', 'creditCard']::text[], array['ofx']::text[], timezone('utc', now()), timezone('utc', now())),
    ('608d9dc0-0df1-8ae0-aa82-ee90c024dcab', '077', 'Banco Inter', 'inter', array['checking', 'creditCard']::text[], array['ofx', 'inter_credit_card_csv']::text[], timezone('utc', now()), timezone('utc', now())),
    ('7affd84d-2678-8b5d-98ec-be3e1a226c69', '102', 'XP Investimentos', 'xp', array['checking']::text[], array['ofx']::text[], timezone('utc', now()), timezone('utc', now())),
    ('504ee282-013f-8b73-9b7f-a54ec6a8b811', '104', 'Caixa Econômica Federal', 'caixa', array['checking', 'creditCard']::text[], array['ofx']::text[], timezone('utc', now()), timezone('utc', now())),
    ('84085364-bc2c-873d-a83b-a71c3b29f5b5', '336', 'C6 Bank', 'c6', array['checking', 'creditCard']::text[], array['ofx']::text[], timezone('utc', now()), timezone('utc', now())),
    ('148f03b9-e514-8f46-b00a-54dadd6006ea', '341', 'Itaú', 'itau', array['checking', 'creditCard']::text[], array['ofx']::text[], timezone('utc', now()), timezone('utc', now()))
on conflict (id) do update set
    code = excluded.code,
    name = excluded.name,
    kind = excluded.kind,
    supported_account_types = excluded.supported_account_types,
    supported_import_formats = excluded.supported_import_formats,
    updated_at = timezone('utc', now());
