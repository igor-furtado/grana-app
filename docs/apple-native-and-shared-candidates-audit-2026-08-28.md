# Auditoria de componentes Apple-style e candidatos a `Shared`

Data: 2026-08-28

## Escopo e método

Esta auditoria cobre a camada SwiftUI do repositório em `GranaApp/App`, `GranaApp/Features` e `GranaApp/Shared`, usando apenas fontes primárias locais: `AGENTS.md`, `CONTEXT.md`, `docs/design-system.md`, `docs/agents/design-system.md`, ADRs relevantes e o código-fonte. O critério foi:

- classificar como Apple-style tudo que usa primitives e fluxos nativos do ecossistema SwiftUI/macOS, mesmo quando encapsulados por wrappers do app;
- classificar como candidato a `Shared` tudo que está fora de `GranaApp/Shared`, já aparece repetido ou já nasceu genérico o suficiente para reutilização transversal;
- descartar views muito específicas de domínio, mesmo quando visualmente boas, se o reaproveitamento provável for baixo.

O design system já determina três pontos que orientam a leitura: `AppUI.Table` é o ponto de entrada obrigatório para tabelas sobre `SwiftUI.Table`, feature screens e sheets podem ocultar a toolbar nativa, e `EmptyStateView` deve ser usado no lugar de `ContentUnavailableView` direto. (`docs/design-system.md:48-64`; `GranaApp/Shared/Components/AppUITable.swift:3-5`; `GranaApp/Shared/Components/EmptyStateView.swift:10-15`)

## 1. Componentes nativos no estilo Apple

### 1.1 Navegação, apresentação e padrões de shell

- `NavigationStack` aparece no shell autenticado com branch preservation em `AppShellBranchView`, alinhado ao ADR do shell autenticado por seção. (`GranaApp/App/ContentView.swift:133-146`; `docs/adr/0009-shell-autenticado-com-branches-preservadas.md:1`)
- `NavigationStack` também aparece em `ImportView`, isolando o fluxo modal de importação em um stack próprio. (`GranaApp/Features/Import/ImportView.swift:12-19`)
- `sheet` é o padrão dominante de apresentação modal no app:
  - wizard global de importação a partir do shell autenticado; (`GranaApp/App/ContentView.swift:219-231`)
  - formulário, arquivamento e exclusão de contas; (`GranaApp/Features/Accounts/AccountsView.swift:33-48`)
  - formulário, arquivamento e exclusão de cartões; (`GranaApp/Features/CreditCards/CreditCardsView.swift:54-69`)
  - exclusão de transação; (`GranaApp/Features/Transactions/TransactionsView.swift:29-34`)
  - editor de datas próprias de fatura. (`GranaApp/Features/CreditCards/Statements/CreditCardStatementsView.swift:48-53`)
- `inspector` aparece explicitamente em `CategoriesView`, com largura de coluna configurada e persistência em `@SceneStorage`, reproduzindo um padrão clássico de app macOS. (`GranaApp/Features/Categories/CategoriesView.swift:21-25`; `GranaApp/Features/Categories/CategoriesView.swift:64-67`)
- `confirmationDialog` é usado para a ação destrutiva de desfazer lote de importação. (`GranaApp/Features/Import/ImportHistoryView.swift:52-75`)
- `contextMenu` aparece no seletor de cartões, concentrando ações secundárias por item. (`GranaApp/Features/CreditCards/CreditCardListView.swift:108-114`)
- `fileImporter` e `dropDestination` são usados como padrões nativos de entrada de arquivo no fluxo de importação. (`GranaApp/Features/Import/ImportView.swift:13-30`; `GranaApp/App/ContentView.swift:210-218`)
- `@SceneStorage` persiste tanto a seção ativa do app quanto a visibilidade do inspector de categorias, dois comportamentos típicos de UX macOS. (`GranaApp/App/ContentView.swift:8-17`; `GranaApp/Features/Categories/CategoriesView.swift:23-25`)

### 1.2 Toolbar e chrome nativo

- O design system manda ocultar a `windowToolbar` nativa quando a tela tem header próprio integrado ao tema. (`docs/design-system.md:60-64`)
- Esse padrão aparece de forma consistente em views de shell e modais: `TransactionListView`, `AccountsView`, `CreditCardsView`, `CategoriesView`, `ImportView`, `ImportHistoryView`, `AccountFormView`, `CreditCardFormView`, `CategorizationReviewView` em modo modal e `StatementDateEditorView`. (`GranaApp/Features/Transactions/TransactionListView.swift:24-30`; `GranaApp/Features/Accounts/AccountsView.swift:33-33`; `GranaApp/Features/CreditCards/CreditCardsView.swift:54-54`; `GranaApp/Features/Categories/CategoriesView.swift:68-72`; `GranaApp/Features/Import/ImportView.swift:59-64`; `GranaApp/Features/Import/ImportHistoryView.swift:50-78`; `GranaApp/Features/Accounts/AccountFormView.swift:31-32`; `GranaApp/Features/CreditCards/CreditCardFormView.swift:31-32`; `GranaApp/Features/Categorization/CategorizationReviewView.swift:20-36`; `GranaApp/Features/CreditCards/Statements/StatementDateEditorView.swift:21-23`)

### 1.3 Formulários e controles de entrada nativos

- `Form` + `Section` estruturam os dois formulários administrativos centrais:
  - `AccountFormView` para identidade, identidade bancária e saldo inicial; (`GranaApp/Features/Accounts/AccountFormView.swift:8-18`; `GranaApp/Features/Accounts/AccountFormView.swift:35-84`)
  - `CreditCardFormView` para identidade, detalhes do cartão e ciclo da fatura. (`GranaApp/Features/CreditCards/CreditCardFormView.swift:7-18`; `GranaApp/Features/CreditCards/CreditCardFormView.swift:35-100`)
- `Picker` aparece em formulários e etapas de revisão:
  - banco da conta; (`GranaApp/Features/Accounts/AccountFormView.swift:35-45`)
  - emissor e dias de fechamento/vencimento do cartão; (`GranaApp/Features/CreditCards/CreditCardFormView.swift:35-87`)
  - conta-cartão na revisão CSV; (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:49-63`)
  - compra original para estorno CSV; (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:206-229`)
  - conta de destino na revisão OFX; (`GranaApp/Features/Import/Steps/OFXReviewStepView.swift:69-87`)
  - seletor segmentado de extrato em revisão OFX multi-`STMTRS`. (`GranaApp/Features/Import/Steps/OFXReviewStepView.swift:225-235`)
- `Toggle` aparece em múltiplos papéis Apple-style:
  - switch de saldo negativo; (`GranaApp/Features/Accounts/AccountFormView.swift:59-71`)
  - switch para informar limite de crédito; (`GranaApp/Features/CreditCards/CreditCardFormView.swift:48-66`)
  - switch de “mostrar arquivadas” na lista de contas; (`GranaApp/Features/Accounts/AccountListView.swift:184-207`)
  - toggle dentro de `Menu` para “mostrar arquivados” em cartões; (`GranaApp/Features/CreditCards/CreditCardsView.swift:21-34`)
  - checkboxes de seleção em CSV e OFX; (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:180-192`; `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:171-180`)
  - checkbox master compartilhado em `TransactionsSelectionRow`; (`GranaApp/Features/Import/Components/TransactionsSelectionRow.swift:15-31`)
  - checkbox de seleção em `TransactionRow` compartilhado. (`GranaApp/Shared/Components/TransactionRow.swift:53-53`)
- `TextField` é usado como primitive nativa em login, formulários e filtros:
  - email em `LoginView`; (`GranaApp/Features/Auth/LoginView.swift:76-76`)
  - agência e número da conta; (`GranaApp/Features/Accounts/AccountFormView.swift:49-56`)
  - últimos quatro dígitos do cartão; (`GranaApp/Features/CreditCards/CreditCardFormView.swift:49-65`)
  - busca em contas, transações e histórico de importação. (`GranaApp/Features/Accounts/AccountListView.swift:149-180`; `GranaApp/Features/Transactions/TransactionListView.swift:342-372`; `GranaApp/Features/Import/ImportHistoryView.swift:316-353`)
- `DatePicker` aparece no editor de datas de fatura e em protótipo do drawer de transações. Como view de app ativa, o uso consolidado está em `StatementDateEditorView`. (`GranaApp/Features/CreditCards/Statements/StatementDateEditorView.swift:93-106`)

### 1.4 Tabelas nativas do macOS

- O design system padroniza que tabelas densas devem passar por `AppUI.Table`, e `AppUI.Table` encapsula `SwiftUI.Table` diretamente. (`docs/design-system.md:48-51`; `GranaApp/Shared/Components/AppUITable.swift:55-82`; `GranaApp/Shared/Components/AppUITable.swift:85-123`)
- Consumidores de `AppUI.Table` encontrados no escopo:
  - lista de contas; (`GranaApp/Features/Accounts/AccountListView.swift:14-87`)
  - lista de transações; (`GranaApp/Features/Transactions/TransactionListView.swift:49-121`)
  - histórico de importação; (`GranaApp/Features/Import/ImportHistoryView.swift:192-264`)
  - revisão CSV; (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:124-178`)
  - revisão OFX; (`GranaApp/Features/Import/Steps/OFXReviewStepView.swift:170-241`)
  - revisão de categorização; (`GranaApp/Features/Categorization/CategorizationReviewView.swift:59-112`)
  - lista de lançamentos da fatura; (`GranaApp/Features/CreditCards/Statements/StatementListView.swift:48-92`)
  - showcase do design system. (`GranaApp/Features/DesignSystem/DesignSystemView.swift:956-986`)

### 1.5 Containers e affordances típicos do ecossistema Apple

- `GroupBox` é usado explicitamente em `CategoriesView` tanto no card selecionável quanto na seção de subcategorias do inspector, e o próprio comentário do código justifica a escolha como agrupamento visual padrão do sistema. (`GranaApp/Features/Categories/CategoriesView.swift:231-241`; `GranaApp/Features/Categories/CategoriesView.swift:242-270`; `GranaApp/Features/Categories/CategoriesView.swift:364-395`)
- `Menu` é o primitive dominante para filtros e edição pontual em tabelas:
  - filtro de instituição em contas; (`GranaApp/Features/Accounts/AccountListView.swift:126-142`)
  - filtros de banco, categoria, período e tipo em transações; (`GranaApp/Features/Transactions/TransactionListView.swift:280-337`; `GranaApp/Features/Transactions/TransactionListView.swift:374-416`)
  - filtro de instituição no histórico de importação; (`GranaApp/Features/Import/ImportHistoryView.swift:279-314`)
  - menus de categoria e subcategoria na revisão de categorização. (`GranaApp/Features/Categorization/CategorizationReviewView.swift:157-204`)
- `ProgressView` aparece como indicador padrão de carregamento e de progresso:
  - restauração de sessão no app; (`GranaApp/App/ContentView.swift:40-46`)
  - carregamentos de `AccountsView`, `CreditCardsView`, `CategoriesView`, `SupportedInstitutionsView`, `ProfileView` e `StatementListView`; (`GranaApp/Features/Accounts/AccountsView.swift:21-30`; `GranaApp/Features/CreditCards/CreditCardsView.swift:90-99`; `GranaApp/Features/Categories/CategoriesView.swift:43-58`; `GranaApp/Features/Institutions/SupportedInstitutionsView.swift:39-54`; `GranaApp/Features/Profile/ProfileView.swift:14-44`; `GranaApp/Features/CreditCards/Statements/StatementListView.swift:20-20`)
  - progresso linear e indeterminado em importação e categorização; (`GranaApp/Features/Import/ImportView.swift:191-220`; `GranaApp/Features/Import/Steps/CategorizingStepView.swift:56-70`)
  - estado de salvamento em `StatementDateEditorView` e `TransactionFormView`. (`GranaApp/Features/CreditCards/Statements/StatementDateEditorView.swift:76-89`; `GranaApp/Features/Transactions/TransactionFormView.swift:147-147`)
- `EmptyStateView` é o equivalente local a `ContentUnavailableView`; a base compartilhada manda usá-lo no lugar da primitive nativa. Não encontrei uso direto de `ContentUnavailableView` nas views SwiftUI do app. (`GranaApp/Shared/Components/EmptyStateView.swift:10-15`; `GranaApp/App/ContentView.swift:49-68`; `GranaApp/Features/Accounts/AccountsView.swift:54-67`; `GranaApp/Features/CreditCards/CreditCardsView.swift:75-87`; `GranaApp/Features/Categories/CategoriesView.swift:43-58`; `GranaApp/Features/Institutions/SupportedInstitutionsView.swift:39-57`; `GranaApp/Features/Categorization/CategorizationReviewView.swift:116-130`; `GranaApp/Features/Transactions/TransactionListView.swift:14-21`; `GranaApp/Features/Dashboard/DashboardView.swift:11-11`)

## 2. Customizações fora de `GranaApp/Shared` com boa chance de virar componente reutilizável

### 2.1 Família de filter bars e controls de filtro

Forte candidato. Hoje existem três implementações paralelas de barra de filtros, todas fora de `Shared`, com a mesma semântica base: label pequena, `Menu` estilizado como chip, `TextField` com ícone de busca, botão de limpar e mesmo shell visual com `RoundedRectangle(cornerRadius: 14)`.

- `AccountListFilterBar` repete `filterChip`, campo de busca e shell de toggle dentro do mesmo dialeto visual. (`GranaApp/Features/Accounts/AccountListView.swift:121-239`)
- `TransactionsFilterBar` repete o mesmo chip de menu e o mesmo campo de busca customizado, mudando apenas o conjunto de filtros. (`GranaApp/Features/Transactions/TransactionListView.swift:263-418`)
- `ImportHistoryFilterBar` repete `filterChip` e `filterSearchField` quase literalmente. (`GranaApp/Features/Import/ImportHistoryView.swift:273-380`)

Leitura: isso já passou do ponto de “estilo local”. O reaproveitamento provável é alto porque o padrão é estrutural, não de domínio.

### 2.2 Infra de wizard multi-etapa ainda confinada à feature de importação

Forte candidato. Vários tipos já nasceram genéricos e já são reutilizados além de um único step:

- `ImportWizardStageScaffold` e `ImportWizardSplitLayout` são shells genéricos para fluxo multi-etapa e já aparecem em CSV, OFX, classificação e revisão. (`GranaApp/Features/Import/ImportWizardComponents.swift:3-63`; `GranaApp/Features/Import/Steps/CSVReviewStepView.swift:13-39`; `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:21-47`; `GranaApp/Features/Import/Steps/CategorizingStepView.swift:13-22`; `GranaApp/Features/Categorization/CategorizationReviewView.swift:37-50`)
- `ImportWizardSectionCard` é um card genérico com título, subtítulo e trailing view, usado em pelo menos quatro pontos de revisão. (`GranaApp/Features/Import/ImportWizardComponents.swift:195-237`; `GranaApp/Features/Import/Steps/CSVReviewStepView.swift:49-63`; `GranaApp/Features/Import/Steps/CSVReviewStepView.swift:124-178`; `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:69-99`; `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:170-241`)
- `ImportWizardTableStatusBadge` já vazou da importação para a revisão de categorização. (`GranaApp/Features/Import/ImportWizardComponents.swift:318-348`; `GranaApp/Features/Import/Steps/CSVReviewStepView.swift:194-200`; `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:205-212`; `GranaApp/Features/Categorization/CategorizationReviewView.swift:60-69`)

Leitura: a genericidade já existe no código. Falta apenas promoção de localização e naming para `Shared`.

### 2.3 Linha de seleção em massa para tabelas de revisão

Bom candidato. `TransactionsSelectionRow` já é compartilhado entre OFX e CSV, mas ainda mora em `Features/Import/Components` em vez de `Shared`.

- O próprio comentário declara compartilhamento entre os dois fluxos. (`GranaApp/Features/Import/Components/TransactionsSelectionRow.swift:3-10`)
- Uso em CSV. (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:172-176`)
- Uso em OFX. (`GranaApp/Features/Import/Steps/OFXReviewStepView.swift:235-239`)

Leitura: o componente já provou reutilização real; a discrepância é apenas organizacional.

### 2.4 Card de escolha de conta/destino em revisões de importação

Bom candidato. `CSVAccountInfoCard` e `OFXAccountInfoCard` resolvem o mesmo problema de UI: um card de “conta de destino” com `Picker` no trailing e metadados abaixo.

- Variante CSV. (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:49-63`)
- Variante OFX. (`GranaApp/Features/Import/Steps/OFXReviewStepView.swift:69-99`)

Leitura: a diferença está no conteúdo auxiliar, não no shell. O miolo específico pode entrar por slot.

### 2.5 Card de tabela de triagem para importação

Bom candidato. `CSVTransactionsListCard` e `OFXTransactionsListCard` repetem a mesma composição macro:

- `ImportWizardSectionCard(title: "Transações")`; (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:124-178`; `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:170-241`)
- tabela com primeira coluna de seleção por checkbox; (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:125-178`; `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:171-223`)
- status da linha com badge “Importar” ou `ImportWizardTableStatusBadge`; (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:194-229`; `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:205-223`)
- `TransactionsSelectionRow` no filter/header bar. (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:172-176`; `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:235-239`)

Leitura: ainda existe diferença de domínio suficiente para não virar um único componente pronto, mas já existe base para um scaffold compartilhado de “triage table card”.

### 2.6 Família de sheets simples de decisão administrativa

Bom candidato. Há duplicação quase literal entre contas e cartões, e uma terceira variante próxima em transações.

- `AccountArchiveView` e `CreditCardArchiveView` são praticamente idênticas: título, mensagem, erro opcional e `BottomActionBar`. (`GranaApp/Features/Accounts/AccountArchiveView.swift:4-36`; `GranaApp/Features/CreditCards/CreditCardArchiveView.swift:4-36`)
- `AccountDeleteView` e `CreditCardDeleteView` repetem a mesma estrutura, mudando apenas o texto. (`GranaApp/Features/Accounts/AccountDeleteView.swift:4-37`; `GranaApp/Features/CreditCards/CreditCardDeleteView.swift:4-37`)
- `TransactionDeleteView` usa shell próprio, mas pertence à mesma família semântica de sheet administrativa destrutiva com header, mensagem de impacto, erro opcional e botões de confirmação/cancelamento. (`GranaApp/Features/Transactions/TransactionDeleteView.swift:7-80`)

Leitura: há espaço claro para um `ConfirmationSheetScaffold` ou `EntityActionSheet` com slots para ícone, mensagem e severidade.

### 2.7 Dropzone e overlays de importação por arraste

Bom candidato. O app mantém duas implementações diferentes da mesma semântica de drag-and-drop/import:

- `GlobalImportDropOverlay` cobre qualquer tela quando há drop global ativo. (`GranaApp/App/ContentView.swift:93-131`; `GranaApp/App/ContentView.swift:210-218`)
- `EmptyStateDropZone` faz o mesmo papel no vazio do histórico de importação e ainda usa `ImportEmptyStateInfoPill` como microcomponente auxiliar. (`GranaApp/Features/Import/ImportHistoryView.swift:383-456`)

Leitura: as duas variam em densidade e contexto, mas compartilham affordances demais para continuarem totalmente separadas.

### 2.8 Indicador de utilização de limite

Bom candidato. O cálculo e a linguagem visual da barra de utilização aparecem em dois lugares fora de `Shared`.

- `CreditCardUsageBar` desenha a barra dentro do card selecionável do cartão. (`GranaApp/Features/CreditCards/CreditCardListView.swift:76-91`; `GranaApp/Features/CreditCards/CreditCardListView.swift:151-166`)
- `LimitGaugeBlock` repete a mesma semântica no detalhe da fatura, com barra, percentuais e valores usados/disponíveis. (`GranaApp/Features/CreditCards/Statements/CreditCardStatementsView.swift:15-21`; `GranaApp/Features/CreditCards/Statements/CreditCardStatementsView.swift:126-204`)

Leitura: a granularidade ideal pode ser um `UsageBar` ou um `UtilizationMeter` com variante compacta e expandida.

## 3. Casos analisados e descartados como `Shared`

- `CategoryCard` e `CategoryInspector` são bons componentes locais, mas estão fortemente acoplados ao catálogo hierárquico de categorias e ao padrão SF Symbols-inspired dessa tela. (`GranaApp/Features/Categories/CategoriesView.swift:221-395`)
- `CreditCardSelectorCard` tem boa execução, mas o conteúdo é específico da entidade cartão, do estado selecionado e do menu contextual dessa vertical. (`GranaApp/Features/CreditCards/CreditCardListView.swift:27-149`)
- `StatementCyclePanel`, `StatementCycleCard` e blocos de timeline de fatura são específicos demais de domínio para entrar em `Shared` neste momento. (`GranaApp/Features/CreditCards/Statements/CreditCardStatementsView.swift:22-44`; `GranaApp/Features/CreditCards/Statements/CreditCardStatementsView.swift:365-589`)

## Conclusão

O repositório usa primitives Apple/macOS de forma consistente, mas quase sempre mediadas por wrappers do próprio app: `AppUI.Table` sobre `SwiftUI.Table`, `EmptyStateView` no lugar de `ContentUnavailableView`, headers inline no lugar da toolbar nativa e `sheet` como mecanismo modal dominante. (`docs/design-system.md:48-64`; `GranaApp/Shared/Components/AppUITable.swift:3-5`; `GranaApp/Shared/Components/EmptyStateView.swift:10-15`)

Os candidatos mais fortes a promoção para `GranaApp/Shared` são:

- a família de filter bars/chips/campos de busca;
- a infraestrutura de wizard multi-etapa hoje presa à importação;
- `TransactionsSelectionRow`;
- a família de sheets simples de confirmação/arquivamento/exclusão;
- os dropzones/overlays de importação;
- a barra/medidor de utilização de limite.
