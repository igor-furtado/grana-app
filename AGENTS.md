# AGENTS.md

Guia operacional e técnico para agentes neste repositório.

## Antes de alterar código

1. Leia este arquivo e `CONTEXT.md`. Consulte ADRs relacionados em `docs/adr/`, quando existirem.
2. Inspecione `git status --short` e preserve mudanças do usuário. Não reverta, reformate nem inclua arquivos alheios.
3. Use `ROADMAP.md` apenas como contexto de planejamento; ele não define regras nem limita pedidos explícitos.
4. Confirme a implementação atual no código, testes, `project.pbxproj`, `.swiftformat` e `.swiftlint.yml`.

`CONTEXT.md` define o vocabulário de domínio. Este arquivo define convenções de implementação. Código e configurações
mostram o estado atual. Em divergências, não normalize silenciosamente: corrija a fonte obsoleta ou sinalize o conflito.

## Stack e escopo técnico

- App exclusivo para macOS, com SwiftUI, Observation (`@Observable`) e Swift Charts.
- Target macOS `26.1`, isolamento padrão `MainActor`.
- Direção aceita: app online-only estrito com Supabase Postgres como fonte única de verdade; veja
  `docs/adr/0007-app-online-only-com-supabase-como-fonte-da-verdade.md`.
- Durante a refatoração, PowerSync pode coexistir apenas para fatias ainda não migradas. Não introduza novo código
  offline-first.
- Testes com Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`).
- IA via backend online de categorização assistida, com provider ativo configurável e integração inicial prevista para OpenAI `gpt-5.4-mini`.
- App Sandbox permanece desativado para permitir `Process`.
- Não adicione dependências nem troque a stack sem pedido explícito.

## Arquitetura

Fluxo obrigatório:

```text
SwiftUI View -> @Observable Store -> Repository -> Supabase backend
```

- Views não executam SQL, não chamam Supabase diretamente nem instanciam repositories.
- Stores recebem `AppContainer`; coordenam estado e operações.
- Repositories concentram chamadas remotas, DTOs e mapeamento entre contratos backend e models.
- `AppContainer` é o composition root e expõe repositories e serviços.
- O app não persiste dados financeiros localmente. Supabase Auth pode manter sessão/token local; dados financeiros só em
  memória durante sessão válida.
- Use `load()` e `refresh()` explícitos por tela. Não introduza `watch()`/Realtime sem decisão específica.
- Telas compostas consomem read models ou RPCs versionadas do backend; não busque histórico inteiro para agregar no Swift.
- Operações consistentes com múltiplas etapas usam RPCs transacionais no backend.
- Tabelas financeiras não recebem escrita direta do app. `INSERT`, `UPDATE` e `DELETE` financeiros passam por funções
  controladas.

## Invariantes de implementação

- Toda transação referencia exatamente uma conta e uma categoria; subcategoria é opcional.
- Dinheiro usa `Decimal` no Swift e `Int64` em centavos no banco. Nunca use `Double`; converta com `Converters`.
- `Transaction.amount` é sempre magnitude positiva; `CategoryKind` determina receita, despesa ou transferência.
- Instantes usam `timestamptz` no backend e `Date` no Swift; datas civis de fatura usam `date`.
- Transferências não entram em cards nem gráficos de receitas e despesas.
- IDs financeiros finais são gerados pelo backend. O app pode enviar IDs temporários ou chaves de idempotência.
- Moeda padrão: BRL.
- `accounts` contém apenas campos universais. Dados específicos ficam em `bank_accounts` e `credit_cards`, escritos
  atomicamente pelo backend.
- Toda transação de cartão exige fatura. Mudança de conta ou data re-resolve o ciclo.
- Datas de fechamento e vencimento de uma fatura são snapshots; mudanças futuras no cartão não as alteram.
- Compra se vincula à fatura por `transactions.statement_id`; pagamento se vincula por `statement_payments`.
- Escritas que afetam compras ou pagamentos recalculam total e status da fatura na mesma transação backend.
- Categorias são hierárquicas. Apenas raízes têm ícone; subcategorias herdam o ícone na UI.
- Categorias e instituições são catálogos globais somente leitura no MVP. O app resolve catálogos por slug/código, não por
  IDs conhecidos.
- Instituições financeiras fora do catálogo suportado bloqueiam criação de conta.

## Convenções Swift e UI

- Use `@Observable`; não introduza `ObservableObject`, `@Published` nem Combine.
- Use `async/await`.
- Estado apenas visual fica em `@State`; dados persistidos ou compartilhados ficam no Store.
- Dados financeiros não podem ser persistidos em `UserDefaults`, arquivos, SQLite, banco local ou caches em disco.
- Mantenha Views pequenas e extraia subviews quando acumularem responsabilidades.
- Não adicione `#Preview`; valide UI executando o app.
- Ícones de UI vêm de `AppIcon`; ícones de categoria passam por `CategoryIcon` e seus mappings.
- Cores novas entram em `Assets.xcassets` com variante dark.
- Erros de domínio são enums `LocalizedError`, com mensagens em PT-BR.
- Comentários explicam decisões e motivos, não narram o código.
- Arquivos com interpolação de `Logger` importam `OSLog`.
- Tipos e arquivos usam `PascalCase`; funções e propriedades, `camelCase`; tabelas e colunas, `snake_case`.
- TODOs usam `// TODO(fase-N): ...`.
- Siga `.swiftformat` e `.swiftlint.yml`; não afrouxe regras customizadas para acomodar uma mudança.

## Feedback e logs

- Toda mensagem visível passa por `NoticeCenter`.
- Relate erros onde forem consumidos. `catch` que relança ou transforma não gera toast.
- `CancellationError` é esperado e permanece silencioso.
- Não faça `log.error` antes de `NoticeCenter.report`; o centro já registra o notice.
- Use as categorias de `Core/Logging/Logger.swift`; não use `print`.
- Nunca registre valores de transações, credenciais ou dados financeiros sensíveis.

## Importação e IA

- `ImportStore.supportedExtensions` é a fonte dos formatos aceitos.
- Importadores aplicam `abs()` antes de persistir valores.
- Preserve as regras existentes de deduplicação por formato.
- Cada `STMTRS` OFX gera um `ImportBatch`; múltiplos extratos são enviados em payload estruturado para commit atômico no
  backend.
- `ImportBatch` permanece reversível, sem transações órfãs.
- A categorização assistida ocorre antes do commit final.
- Deduplicação de importação é garantia backend com função e constraint; duplicatas são puladas com relatório.
- Não troque o backend online de categorização assistida, o provider inicial suportado nem a política de pseudonimização sem decisão explícita.

## Onde alterar

| Necessidade | Local principal |
|---|---|
| Nova tabela, RLS, função ou seed global | migrations Supabase versionadas no repo |
| Novo read model ou mutação financeira | schema `api`/RPC versionada e repository remoto |
| Nova categoria padrão | seed/migration Supabase de catálogo global |
| Novo formato de importação | `GranaApp/Core/Import/`, `ImportStore` e step de revisão |
| Novo repository ou serviço | Registro no `AppContainer` |
| Novo ícone de UI | `GranaApp/Shared/Components/AppIcon.swift` |
| Novo ícone de categoria | `GranaApp/Models/Category.swift` e extensions de `CategoryIcon` |
| Feedback ao usuário | `NoticeCenter` |
| Nova categoria de log | `GranaApp/Core/Logging/Logger.swift` |

## Configuração e validação

Quando necessário, crie a configuração local a partir do template:

```bash
cp GranaApp/Config.example.swift GranaApp/Config.swift
```

`Config.swift` permanece ignorado pelo Git.

```bash
xcodebuild \
  -project GranaApp.xcodeproj \
  -scheme GranaApp \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/GranaAppDerivedData \
  build

xcodebuild \
  -project GranaApp.xcodeproj \
  -scheme GranaApp \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/GranaAppDerivedData \
  test

swiftformat --lint .
swiftlint
```

- Rode primeiro a validação mais estreita que cobre a mudança; amplie para build e testes completos quando o impacto for
  transversal.
- Teste regras de domínio, parsers, conversões, queries e regressões.
- Para repositories remotos, use clients fake em testes Swift. Testes backend, scripts SQL e verificações formais de
  backend não são requisito nesta refatoração; mudanças backend dependem de revisão de código/contrato e dos testes do app.
- Migrations que alteram RLS, grants, RPCs financeiras ou schema financeiro devem ser pequenas, revisáveis e acompanhadas
  de plano de rollback manual no PR/issue. Sem testes backend, revisão humana é o gate principal dessas mudanças.
- Injete `Calendar` em comportamento dependente de dia ou fuso.
- Informe validações não executadas.
- Não faça stage, commit, push, mudanças destrutivas de banco nem alterações de dependências sem pedido explícito.

## Agent skills

### Issue tracker

Issues e PRDs são rastreados no GitHub Issues via `gh`. Veja `docs/agents/issue-tracker.md`.

### Triage labels

Usa os cinco rótulos canônicos no GitHub Issues. Veja `docs/agents/triage-labels.md`.

### Domain docs

Layout single-context. Veja `docs/agents/domain.md`.
