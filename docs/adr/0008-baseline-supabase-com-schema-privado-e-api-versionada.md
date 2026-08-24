# Baseline Supabase com schema privado e API versionada

Status: accepted

## Contexto

O projeto Supabase foi recriado do zero após a remoção do modelo local-first e
da categorização remota. Não há necessidade de preservar compatibilidade
in-place com a cadeia histórica de migrations antigas.

## Decisão

O baseline Supabase é limpo e versionado por migrations no repositório. Objetos
de produto não vivem como contrato no schema `public`.

- `api`: superfície consumida pelo GranaApp, com views e funções `v1_*`.
- `app_private`: tabelas base, catálogos, perfil, idempotência, helpers e lógica
  interna.

O app consome catálogos por views `api.v1_category_catalog` e
`api.v1_supported_institution_catalog`. Dados financeiros são acessados por
RPCs e read models em `api`, não por escrita direta nas tabelas base.

Edge Functions não fazem parte do baseline atual. Categorização inteligente por
IA fica fora do GranaApp e fora do backend remoto de categorização; a fronteira
vigente está registrada em `docs/adr/0009-granaapp-sem-ia-remota.md`.

## Consequências

- Bootstrap de banco é mais simples: aplicar migrations recria o estado atual
  esperado.
- Contratos públicos do app ficam explícitos em `api.v1_*`.
- Estruturas internas podem mudar sem quebrar o app, desde que o contrato em
  `api` seja preservado ou versionado.
- Migrations antigas de PowerSync, IA remota e compatibilidade local não devem
  ser reintroduzidas.
