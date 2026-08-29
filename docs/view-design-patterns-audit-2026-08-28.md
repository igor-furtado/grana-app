# Auditoria de Padrões de Design das Views

Data: 2026-08-28

## Escopo e método

Esta auditoria infere padrões a partir do próprio código-fonte das views SwiftUI do app e das fontes normativas do repositório. O foco ficou em `GranaApp/App`, `GranaApp/Features` e `GranaApp/Shared/Components`, porque `ContentView` é a raiz, `AuthenticatedShellView` monta as telas de seção a partir de `Features`, e os blocos visuais reutilizáveis vivem em `Shared/Components`. Protótipos HTML não entraram na amostra porque o pedido restringiu as fontes primárias ao código do app e aos documentos listados. (Fontes: `AGENTS.md:28-30`, `GranaApp/App/ContentView.swift:4-91`, `GranaApp/App/ContentView.swift:149-279`)

A skill `research` pede um agente em background, mas nesta sessão não havia ferramenta específica de subagente disponível; a pesquisa foi executada diretamente, mantendo a restrição de usar apenas fontes primárias locais. (Fonte: `research/SKILL.md` fornecida no prompt do usuário)

## Padrões predominantes

### 1. Shell predominante das telas autenticadas: header inline da feature no topo

Critérios observáveis:

- a tela principal começa com `VStack(spacing: GranaTheme.Spacing.sm)`;
- o primeiro bloco útil é `FeatureScreenHeader`;
- a window toolbar nativa é ocultada com `.toolbar(.hidden, for: .windowToolbar)`;
- o conteúdo principal vem logo abaixo do header, ocupando o restante da área.  
  (Fontes: `docs/design-system.md:45-56`, `docs/agents/design-system.md:8-13`, `GranaApp/Shared/Components/FeatureScreenHeader.swift:3-44`)

Esse shell aparece de forma consistente em `AccountsView`, `CreditCardsView`, `TransactionListView`, `ImportHistoryView`, `CategoriesView`, `SupportedInstitutionsView`, `DashboardView` e `ProfileView`. Em todos eles, o header vem antes do conteúdo e concentra título, subtítulo e ações primárias. (Fontes: `GranaApp/Features/Accounts/AccountsView.swift:7-33`, `GranaApp/Features/CreditCards/CreditCardsView.swift:7-54`, `GranaApp/Features/Transactions/TransactionListView.swift:33-123`, `GranaApp/Features/Import/ImportHistoryView.swift:35-103`, `GranaApp/Features/Categories/CategoriesView.swift:39-100`, `GranaApp/Features/Institutions/SupportedInstitutionsView.swift:26-39`, `GranaApp/Features/Dashboard/DashboardView.swift:4-23`, `GranaApp/Features/Profile/ProfileView.swift:34-73`)

### 2. Padrão predominante para coleções densas: `AppUI.Table` como superfície principal

Critérios observáveis:

- listas operacionais e tabelares usam `AppUI.Table` em vez de `SwiftUI.Table` direto;
- filtros, seleção e ordenação ficam fora do wrapper, mas plugados na `filterBar` ou nas bindings da tela;
- ações por linha aparecem dentro da própria tabela.  
  (Fontes: `docs/design-system.md:31-37`, `docs/agents/design-system.md:10-13`, `GranaApp/Shared/Components/AppUITable.swift:3-42`)

Esse padrão domina as telas de leitura operacional: transações, contas, histórico de importação, revisão de OFX, revisão de CSV, revisão de categorização e lançamentos de fatura. (Fontes: `GranaApp/Features/Transactions/TransactionListView.swift:49-121`, `GranaApp/Features/Accounts/AccountListView.swift:14-88`, `GranaApp/Features/Import/ImportHistoryView.swift:192-260`, `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:169-221`, `GranaApp/Features/Import/Steps/CSVReviewStepView.swift:131-181`, `GranaApp/Features/Categorization/CategorizationReviewView.swift:59-113`, `GranaApp/Features/CreditCards/Statements/StatementListView.swift:47-105`)

### 3. Padrão predominante para estados vazios e indisponibilidade: `EmptyStateView`

Critérios observáveis:

- o estado vazio usa `EmptyStateView`, não `ContentUnavailableView`;
- o componente centraliza ícone grande, título, descrição e ações opcionais;
- o componente ocupa a área restante da tela para funcionar como estado de tela, não só de bloco.  
  (Fontes: `GranaApp/Shared/Components/EmptyStateView.swift:10-65`, `GranaApp/Shared/Components/EmptyStateView.swift:133-145`)

Esse padrão aparece em raiz indisponível, dashboard, contas, cartões, categorias, instituições, perfil, transações e revisão de categorização. (Fontes: `GranaApp/App/ContentView.swift:49-71`, `GranaApp/Features/Dashboard/DashboardView.swift:11-19`, `GranaApp/Features/Accounts/AccountsView.swift:54-67`, `GranaApp/Features/CreditCards/CreditCardsView.swift:75-88`, `GranaApp/Features/Categories/CategoriesView.swift:43-59`, `GranaApp/Features/Institutions/SupportedInstitutionsView.swift:41-57`, `GranaApp/Features/Profile/ProfileView.swift:16-27`, `GranaApp/Features/Transactions/TransactionListView.swift:14-22`, `GranaApp/Features/Categorization/CategorizationReviewView.swift:116-130`)

### 4. Padrão predominante para fluxos modais/editáveis: ações no rodapé com `BottomActionBar`

Critérios observáveis:

- a área de ação fica ancorada no rodapé;
- `Cancelar` e a ação principal ficam agrupados no trailing;
- o componente compartilhado evita drift entre sheet, wizard e revisão.  
  (Fontes: `GranaApp/Shared/Components/BottomActionBar.swift:3-50`)

Esse padrão domina `CreditCardFormView`, `TransactionFormView`, `AccountArchiveView`, `AccountDeleteView`, `CreditCardArchiveView`, `CreditCardDeleteView` e o modo modal de `CategorizationReviewView`. (Fontes: `GranaApp/Features/CreditCards/CreditCardFormView.swift:7-33`, `GranaApp/Features/Transactions/TransactionFormView.swift:134-157`, `GranaApp/Features/Accounts/AccountArchiveView.swift:7-36`, `GranaApp/Features/Accounts/AccountDeleteView.swift:7-37`, `GranaApp/Features/CreditCards/CreditCardArchiveView.swift:7-36`, `GranaApp/Features/CreditCards/CreditCardDeleteView.swift:7-37`, `GranaApp/Features/Categorization/CategorizationReviewView.swift:20-36`)

### 5. Padrão predominante do wizard de importação: scaffold próprio, sem lógica espalhada na view

Critérios observáveis:

- o wizard usa `ImportWizardStageScaffold` como casca externa;
- fluxos com múltiplas etapas usam `ImportWizardSplitLayout` com sidebar semântica das etapas;
- a view renderiza estado e delega coordenação ao reducer/store, alinhado ao ADR de TCA para fluxos complexos.  
  (Fontes: `AGENTS.md:33-37`, `docs/adr/0007-tca-para-features-stateful-novas-ou-migradas.md:13-31`, `GranaApp/Features/Import/ImportWizardComponents.swift:3-95`, `GranaApp/Features/Import/ImportView.swift:74-140`, `GranaApp/Features/Categorization/CategorizationReviewView.swift:37-50`)

### 6. Padrão predominante de linguagem visual: tokens e componentes semânticos

Critérios observáveis:

- texto usa `GranaTheme.Typography`;
- spacing usa `GranaTheme.Spacing`;
- ícones de UI passam por `AppIcon`, `InstitutionIcon` ou componentes dedicados;
- tabelas e estados vazios passam por wrappers compartilhados, não por primitivas cruas.  
  (Fontes: `AGENTS.md:54-60`, `docs/design-system.md:55-88`, `docs/design-system.md:89-109`, `docs/agents/design-system.md:3-13`)

Esse é o padrão dominante do repositório como um todo, inclusive em componentes-base como `FeatureScreenHeader`, `AppUI.Table`, `EmptyStateView`, `TransactionRow` e `NoticeCard`. (Fontes: `GranaApp/Shared/Components/FeatureScreenHeader.swift:31-57`, `GranaApp/Shared/Components/AppUITable.swift:22-42`, `GranaApp/Shared/Components/EmptyStateView.swift:33-81`, `GranaApp/Shared/Components/TransactionRow.swift:50-116`, `GranaApp/Shared/Components/NoticeOverlay.swift:42-109`)

## Itens fora do padrão

### 3. `AccountFormView` foge do padrão predominante de rodapé modal com `BottomActionBar`

Evidência:

- `AccountFormView` usa `Form` e, no rodapé, empilha dois `Button`s em um `VStack` simples, sem `BottomActionBar`, sem estilo explícito no botão de cancelar e sem alinhamento trailing padronizado. (Fonte: `GranaApp/Features/Accounts/AccountFormView.swift:8-33`)
- `CreditCardFormView`, que é o formulário paralelo mais próximo, usa `BottomActionBar`. (Fonte: `GranaApp/Features/CreditCards/CreditCardFormView.swift:7-33`)
- O mesmo padrão de rodapé compartilhado reaparece nos outros modais de edição/confirmação. (Fontes: `GranaApp/Features/Transactions/TransactionFormView.swift:134-157`, `GranaApp/Features/Accounts/AccountArchiveView.swift:23-32`, `GranaApp/Features/CreditCards/CreditCardDeleteView.swift:23-32`)

Por que está fora do padrão:

- Entre superfícies modais editáveis, o padrão predominante é conteúdo acima e `BottomActionBar` no rodapé.
- `AccountFormView` é o único formulário desse grupo que quebra esse rodapé compartilhado. (Fontes: `GranaApp/Shared/Components/BottomActionBar.swift:3-50`, `GranaApp/Features/Accounts/AccountFormView.swift:8-33`)

### 4. `TransactionDeleteView` foge do padrão predominante dos modais de confirmação

Evidência:

- A view monta shell próprio com `ZStack`, `GranaBackground`, header bespoke, bloco de mensagem e uma `HStack` manual de ações. (Fonte: `GranaApp/Features/Transactions/TransactionDeleteView.swift:7-80`)
- Os modais de confirmação análogos de conta/cartão usam estrutura mais simples com conteúdo textual e `BottomActionBar`. (Fontes: `GranaApp/Features/Accounts/AccountDeleteView.swift:7-37`, `GranaApp/Features/CreditCards/CreditCardDeleteView.swift:7-37`)

Por que está fora do padrão:

- No contexto “confirmação curta em sheet”, o padrão dominante é rodapé compartilhado e composição enxuta.
- `TransactionDeleteView` introduz um shell visual próprio e abandona o componente compartilhado do rodapé. (Fontes: `GranaApp/Shared/Components/BottomActionBar.swift:3-50`, `GranaApp/Features/Transactions/TransactionDeleteView.swift:7-80`)

### 5. `StatementDateEditorView` foge do padrão predominante dos modais de edição curta

Evidência:

- A view usa `ZStack`, `GranaBackground`, bloco explicativo próprio e uma `HStack` manual para as ações. (Fonte: `GranaApp/Features/CreditCards/Statements/StatementDateEditorView.swift:8-91`)
- Em modais curtos do app, o padrão mais recorrente usa `BottomActionBar` como rodapé compartilhado. (Fontes: `GranaApp/Features/CreditCards/CreditCardFormView.swift:20-29`, `GranaApp/Features/Accounts/AccountArchiveView.swift:23-32`, `GranaApp/Features/CreditCards/CreditCardArchiveView.swift:23-32`)

Por que está fora do padrão:

- Semânticamente, esta é uma edição curta em sheet, comparável a outros fluxos modais compactos.
- O shell e o rodapé são bespoke, enquanto o padrão predominante do grupo é o rodapé padronizado. (Fontes: `GranaApp/Shared/Components/BottomActionBar.swift:3-50`, `GranaApp/Features/CreditCards/Statements/StatementDateEditorView.swift:8-91`)

### 6. `AccountListView` duplica cabeçalho em um contexto que já recebeu `FeatureScreenHeader` da tela pai

Evidência:

- `AccountsView` já abre a seção com `FeatureScreenHeader`. (Fonte: `GranaApp/Features/Accounts/AccountsView.swift:7-20`)
- `AccountListView` acrescenta `panelHeader` antes da `AppUI.Table`, com novo título, texto explicativo e badge de contagem. (Fonte: `GranaApp/Features/Accounts/AccountListView.swift:10-118`)
- Nas telas tabulares equivalentes, a `AppUI.Table` vem logo abaixo do header da feature, sem um segundo cabeçalho estrutural do mesmo peso. (Fontes: `GranaApp/Features/Transactions/TransactionListView.swift:33-123`, `GranaApp/Features/Import/ImportHistoryView.swift:81-115`, `GranaApp/Features/Categorization/CategorizationReviewView.swift:54-113`)

Por que está fora do padrão:

- O padrão predominante é “um header de feature por tela raiz” e, abaixo dele, a superfície de trabalho.
- `AccountListView` é o único caso claro de dupla camada de cabeçalho estrutural dentro do mesmo fluxo principal. (Fontes: `GranaApp/Shared/Components/FeatureScreenHeader.swift:3-44`, `GranaApp/Features/Accounts/AccountListView.swift:10-118`)

### 7. `NoticeCard` viola a regra predominante de spacing tokenizado

Evidência:

- O design system exige `GranaTheme.Spacing` para todo `spacing`, `padding`, `EdgeInsets` e gaps. (Fontes: `docs/design-system.md:89-109`, `docs/agents/design-system.md:5-7`)
- `NoticeCard` usa `.padding(.vertical, 12)` e `.padding(.leading, 2)` no acento lateral. (Fonte: `GranaApp/Shared/Components/NoticeOverlay.swift:84-90`)

Por que está fora do padrão:

- O padrão visual predominante do repositório é tokenizar spacing.
- Esses dois valores numéricos quebram a convenção explícita e tornam `NoticeCard` discrepante do restante da base. (Fontes: `AGENTS.md:58-60`, `docs/design-system.md:89-109`, `GranaApp/Shared/Components/NoticeOverlay.swift:84-90`)

### 8. `CategoryBadge` viola a regra predominante de spacing tokenizado no ícone do badge

Evidência:

- A regra documental também cobre `padding`. (Fontes: `docs/design-system.md:89-109`, `docs/agents/design-system.md:5-7`)
- Em `iconOnlyBody`, o glyph usa `.padding(size * 0.25)`. (Fonte: `GranaApp/Shared/Components/CategoryBadge.swift:31-45`)

Por que está fora do padrão:

- O padrão predominante é usar `GranaTheme.Spacing` para o respiro interno.
- Aqui o padding é calculado ad hoc a partir do tamanho do badge; isso foge da convenção declarada, mesmo que o resultado visual possa ser aceitável. (Fontes: `AGENTS.md:58-60`, `docs/design-system.md:89-109`, `GranaApp/Shared/Components/CategoryBadge.swift:31-45`)

## Conclusão curta

Os padrões mais estáveis do repositório hoje são: header inline padronizado para telas autenticadas, `AppUI.Table` para coleções densas, `EmptyStateView` para estados vazios, `BottomActionBar` para rodapés modais e uso sistemático de tokens/componentes semânticos. Os desvios mais relevantes concentram-se em quatro áreas: uma seção raiz sem `FeatureScreenHeader` (`DesignSystemView`), modais que ignoram `BottomActionBar` (`AccountFormView`, `TransactionDeleteView`, `StatementDateEditorView`) e dois casos de spacing não tokenizado (`NoticeCard`, `CategoryBadge`). (Fontes: citadas nas seções anteriores)
