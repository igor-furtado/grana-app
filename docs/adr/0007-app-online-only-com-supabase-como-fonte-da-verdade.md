# App online-only com Supabase como fonte da verdade

Status: accepted

## Contexto

O GranaApp é um app macOS de finanças pessoais. O produto organiza dados
financeiros de um usuário autenticado, mas não movimenta dinheiro. A versão
atual abandonou o modelo local-first: não há PowerSync, SQLite, schema local,
seeds financeiras locais nem modo demo offline no fluxo real.

O requisito de privacidade vigente é não enviar transações para provedores
externos de IA. O Supabase continua recebendo dados financeiros porque é a fonte
de verdade do produto.

## Decisão

O GranaApp opera em modo online-only estrito. Sem sessão remota válida ou sem
conseguir validar a disponibilidade do backend, o app não exibe nem edita dados
financeiros. Supabase Auth pode manter sessão/token local; dados financeiros só
ficam no Supabase ou em memória durante uma sessão válida.

O Supabase Postgres é a fonte única de verdade para contas, transações, faturas,
categorias, instituições, lotes de importação, perfil e idempotência. O app usa
`supabase-swift` contra o schema `api`, com DTOs Swift manuais e contratos
versionados `v1`.

O fluxo de app permanece:

```text
SwiftUI View -> @Observable Store -> Repository -> Supabase backend
```

Views não chamam Supabase diretamente. Stores recebem `AppContainer`,
coordenam estado e chamam repositories. Repositories concentram Data API, RPCs,
DTOs e mapeamento de erros.

## Backend

O schema `api` é a superfície consumida pelo app. Tabelas base, helpers e lógica
interna ficam em `app_private`. Tabelas financeiras não recebem escrita direta
do app; mutações financeiras passam por RPCs transacionais.

Catálogos globais de categorias e instituições ficam em `app_private` e são
expostos por views `api.v1_*`. Eles são somente leitura para usuários
autenticados e alterados por migrations/admin. O app resolve catálogos por
`slug` ou `code`, não por IDs conhecidos.

Tabelas financeiras têm propriedade por `user_id` e RLS baseada em `auth.uid()`.
Quando uma função privilegiada for necessária, ela deve ter escopo estreito,
validar o usuário explicitamente e ter grants revisáveis. O schema `public` não
é contrato de produto.

Read models e RPCs atuais cobrem catálogos, perfil, contas, transações,
faturas, dashboard e importação. Listas grandes usam paginação por cursor;
transações ordenam por `occurred_at desc, created_at desc, id desc`.

## Domínio financeiro

Valores monetários são `Int64` em centavos no banco e `Decimal` no Swift.
Instantes usam `timestamptz`; datas civis de fatura usam `date`.

Toda transação referencia exatamente uma conta e uma categoria; subcategoria é
opcional. O valor da transação é magnitude positiva; `CategoryKind` determina
receita, despesa ou transferência. Transferências não entram em cards nem
gráficos de receitas/despesas.

Faturas são materializadas no backend com snapshots de fechamento e vencimento,
totais e status. As decisões de propagação de saldo credor e recálculo
cronológico continuam válidas e são implementadas no backend.

## Importação e classificação

Parsing e preview de OFX/CSV ficam no GranaApp. Cada `STMTRS` OFX gera um
`ImportBatch`; múltiplos extratos são enviados como payload estruturado para
commit atômico no backend.

O payload de importação é tratado como não confiável. O backend revalida conta,
categoria, instituição, duplicidade, fatura e estorno antes de persistir.
Deduplicação é garantia canônica do backend por função e constraint única; o
commit pula duplicatas e retorna relatório.

O GranaApp não chama Edge Function de categorização nem provedor externo de IA.
Enquanto o projeto local de inteligência não existir, a classificação pré-commit
é um fallback local em **Não Classificado**, seguido de revisão manual.

## UI e falhas

Telas usam `load()` e `refresh()` explícitos. Não há `watch()`/Realtime no
estado atual. Após mutações bem-sucedidas, stores recarregam read models
afetados. O MVP não usa optimistic UI para mutações financeiras.

Falha de rede ou timeout mostra indisponibilidade global com ação de tentar
novamente, sem navegação para áreas financeiras. Token inválido ou sessão
expirada sem refresh possível retorna ao login.

## Consequências

- O app fica mais simples e previsível, mas depende de conectividade para uso
  real.
- Privacidade contra provedores externos de IA é preservada no GranaApp.
- A superfície crítica migra para Postgres: RLS, grants, constraints e RPCs
  precisam de revisão humana cuidadosa.
- Testes automatizados focam a camada Swift remota com clients fake. Testes
  backend automatizados, scripts SQL e verificações formais não são requisito
  desta fase, mas essa decisão deve ser reavaliada antes de usuários reais.
- Migrations que alterem RLS, grants, RPCs financeiras ou schema financeiro
  devem ser pequenas, revisáveis e acompanhadas de plano de rollback manual.
