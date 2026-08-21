# Plano da refatoração online-only Supabase

Este plano operacionaliza a decisão registrada em `docs/adr/0007-app-online-only-com-supabase-como-fonte-da-verdade.md`.
A ADR explica o porquê; este documento guia a ordem de execução.

## Estratégia

A refatoração deve avançar por fatias verticais. Em cada fatia, crie primeiro o contrato backend, migre a feature no app e
remova o equivalente local daquela área. PowerSync pode coexistir temporariamente apenas para fatias ainda não migradas.
Não use feature flag local/remoto: como não há usuários reais nem migração de dados, cada fatia migra direto para o modelo
remoto.

Cada fatia deve terminar compilando e com a validação mais estreita executada. O estado final da refatoração exige build sem
PowerSync e sem banco financeiro local.

Como backend não terá testes automatizados, scripts SQL ou verificação formal nesta refatoração, migrations sensíveis devem
ser pequenas e revisáveis. Mudanças em RLS, grants, RPCs financeiras ou schema financeiro precisam de revisão humana
cuidadosa e plano de rollback manual no PR/issue.

## Fase 1: base Supabase

- Criar estrutura Supabase no repo com migrations versionadas.
- Criar schemas `api` para a superfície consumida pelo app e `app_private` para tabelas base, helpers e lógica interna.
- Configurar grants mínimos, RLS e revogação de exposição não intencional.
- Criar catálogos globais somente leitura de categorias e instituições suportadas.
- Expor catálogos globais por views em `api`, mantendo tabelas base em `app_private`.
- Declarar capacidades das instituições suportadas: tipos de conta e formatos de importação aceitos.
- Criar RPC idempotente `api.v1_ensure_profile()` para perfil/configuração mínima no primeiro boot autenticado.
- Persistir timezone padrão do usuário e permitir override por request em agregações.

## Fase 2: catálogos e contas

- Expor read models de categorias e instituições globais.
- Criar RPCs versionadas para criar, editar e excluir contas.
- Bloquear criação de conta para instituição financeira não suportada.
- Bloquear exclusão de conta com transações, faturas ou importações.
- Migrar repositories/stores de contas para Supabase remoto com `load()` e `refresh()`.
- Remover uso de seeds locais de categorias/instituições nessa fatia.

## Fase 3: transações e faturas

- Criar tabelas financeiras com `user_id`, RLS e sem escrita direta pelo app.
- Criar RPCs versionadas para criar, editar e excluir transações.
- Materializar faturas no backend com snapshots, totais, status e data de quitação.
- Migrar as regras de saldo credor e recálculo cronológico para funções backend.
- Expor read models paginados para lista de transações, detalhes de fatura e pagamentos.
- Usar paginação por cursor; transações ordenam por `occurred_at desc, created_at desc, id desc`.

## Fase 4: dashboard

- Criar RPC/read models de agregações por período.
- Garantir que transferências não entram em receitas/despesas.
- Migrar dashboard para buscar agregações prontas, sem somar histórico inteiro no Swift.

## Fase 5: importação e IA

- Manter parsing e preview OFX/CSV no app.
- Enviar payload estruturado revisado para commit atômico no backend.
- Validar no backend conta, categoria, instituição, duplicidade, fatura e estorno.
- Implementar deduplicação por função e constraint única adequada.
- Pular duplicatas e retornar relatório.
- Persistir `ImportBatch` no backend para desfazer importação sem transações órfãs.
- Usar `idempotency_key` por usuário e operação para retries de importação.
- Manter pseudonimização semântica sob autoridade do backend antes de chamar providers externos.

## Fase 6: remoção PowerSync e limpeza local

- Remover PowerSync do projeto Xcode, imports, testes e resolução de pacotes.
- Remover uso funcional de SQLite, `watch()`, `AppSchema`, schema local e seeds locais.
- Remover ação de apagar banco local da UI.
- Limpar arquivos antigos `grana_ai.sqlite`, `-wal` e `-shm` no primeiro boot pós-refatoração.
- Manter `Converters` apenas para `Decimal` no Swift e centavos inteiros nos DTOs remotos.
- Garantir que dados financeiros não sejam persistidos em `UserDefaults`, arquivos, banco local ou caches em disco.

## Critérios finais de aceite

- O app compila sem PowerSync.
- Não há persistência local de dados financeiros.
- Supabase Postgres é a fonte única de verdade.
- Login online-only funciona com tela global de indisponibilidade para falha de rede e login para sessão inválida.
- Contas, transações, faturas, dashboard e importação usam backend.
- Tabelas financeiras não têm escrita direta pelo app.
- Read models e RPCs são versionados e revisáveis por código/contrato.
- Testes cobrem a camada Swift remota com clients fake; testes backend automatizados, scripts SQL e verificações formais
  de backend não são requisito desta refatoração.
- Mudanças sensíveis de backend têm revisão humana e plano de rollback manual.
