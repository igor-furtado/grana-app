# Baseline Supabase com schema privado e API versionada

O baseline Supabase é limpo e versionado por migrations no repositório. Objetos
de produto não vivem como contrato no schema `public`.

- `api`: superfície consumida pelo GranaApp, com views e funções `v1_*`.
- `app_private`: tabelas base, catálogos, perfil, idempotência, helpers e lógica
  interna.

O app consome catálogos por views `api.v1_category_catalog` e
`api.v1_supported_institution_catalog`. Dados financeiros são acessados por
RPCs e read models em `api`, não por escrita direta nas tabelas base.

Edge Functions não fazem parte do baseline atual. Estruturas internas podem
mudar sem quebrar o app, desde que o contrato em `api` seja preservado ou
versionado.
