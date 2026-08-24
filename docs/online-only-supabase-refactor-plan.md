# Estado online-only Supabase

Este documento registra o estado atual alcançado pela refatoração descrita em
`docs/adr/0007-app-online-only-com-supabase-como-fonte-da-verdade.md`. Ele não é
mais um plano de migração local-first para remoto; é um checklist operacional
para manter o GranaApp alinhado ao modelo online-only.

## Estado atual

- O GranaApp compila sem PowerSync, SQLite, schema local ou seeds financeiras
  locais.
- Supabase Postgres é a fonte única de verdade para dados financeiros.
- Supabase Auth controla sessão remota; sem sessão válida, o app não exibe
  dados financeiros.
- O app mantém dados financeiros apenas em memória durante a sessão.
- Views SwiftUI falam com Stores; Stores falam com repositories; repositories
  falam com Supabase.
- O schema `api` expõe contratos `v1_*`; `app_private` guarda tabelas base,
  helpers e lógica interna.
- O GranaApp não chama Edge Functions de categorização nem provedores externos
  de IA.

## Superfície backend atual

### Base

- Migrations Supabase versionadas no repo.
- Schemas `api` e `app_private`.
- Grants mínimos, RLS e revogação de exposição não intencional.
- RPC idempotente `api.v1_ensure_profile()` para perfil mínimo no primeiro boot
  autenticado.

### Catálogos e contas

- Catálogos globais de categorias e instituições em `app_private`.
- Views `api.v1_category_catalog` e `api.v1_supported_institution_catalog`.
- Instituições declaram capacidades suportadas: tipos de conta e formatos de
  importação.
- RPCs versionadas para listar, criar, editar e excluir contas.
- Criação de conta bloqueada para instituição não suportada.
- Exclusão de conta bloqueada quando há transações, faturas ou importações.

### Transações e faturas

- Tabelas financeiras com `user_id` e RLS.
- Escritas financeiras mediadas por RPCs, sem escrita direta do app.
- Faturas materializadas no backend com snapshots, totais, status e data de
  quitação.
- Saldo credor e recálculo cronológico implementados no backend.
- Read models para lista de transações, faturas, pagamentos e detalhes.
- Paginação por cursor em listas grandes.

### Dashboard

- Dashboard consome agregações prontas por período.
- Transferências não entram em receitas/despesas.
- O app não busca histórico inteiro para somar em Swift.
- Timezone vem do perfil, com override por request quando necessário.

### Importação e classificação

- Parsing e preview OFX/CSV ficam no app.
- Commit de importação usa payload estruturado e `idempotency_key`.
- Backend revalida conta, categoria, instituição, duplicidade, fatura e estorno.
- Deduplicação é garantida por função e constraint única.
- `ImportBatch` é persistido para permitir desfazer importação sem transações
  órfãs.
- Enquanto o projeto local de inteligência não existir, transações entram como
  **Não Classificado** e passam por revisão manual.

## Regras para próximas mudanças

- Não reintroduzir PowerSync, SQLite, `watch()`, schema local ou persistência
  financeira em disco.
- Não persistir dados financeiros em `UserDefaults`, arquivos, banco local ou
  caches em disco.
- Não chamar APIs públicas de IA a partir do GranaApp.
- Não expor tabelas financeiras base como contrato do app.
- Criar ou alterar contratos backend por migrations pequenas e revisáveis.
- Manter RPCs e read models versionados.
- Usar clients fake nos testes Swift de repositories/stores.
- Mudanças em RLS, grants, RPCs financeiras ou schema financeiro precisam de
  revisão humana cuidadosa e plano de rollback manual.

## Critérios de saúde

- `xcodebuild build` passa.
- `xcodebuild test` passa.
- Buscas por PowerSync, SQLite, Edge Function de categorização e runtime de IA
  remota não retornam uso funcional.
- O app permanece capaz de importar, revisar, commitar e desfazer lotes usando
  o backend.
