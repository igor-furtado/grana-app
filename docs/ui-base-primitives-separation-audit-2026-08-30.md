# Auditoria de Separação para Módulo de UI Base / Primitives

Data: 2026-08-30

## Método

Esta auditoria usou apenas fontes primárias locais do repositório: `AGENTS.md`, `CONTEXT.md`, `docs/design-system.md`, `docs/agents/design-system.md`, ADRs relevantes e o código em `GranaApp/App`, `GranaApp/Features` e `GranaApp/Shared`. O critério foi comparar a fronteira normativa de `AppUI.*` como fachada de primitives visuais com a implementação atual, procurando três classes de desvio: views de feature carregando shell visual reutilizável, componentes compartilhados carregando semântica de feature/domínio e componentes híbridos que hoje misturam as duas camadas. (`AGENTS.md:87-96`, `docs/design-system.md:43-52`, `docs/agents/design-system.md:32-40`, `docs/adr/0010-appui-como-fachada-de-primitives-visuais.md:18-33`, `docs/adr/0012-formularios-densos-com-form-nativo-em-sheet.md:24-31`)

## Critérios

- Primitive base: wrappers visuais e controles reutilizáveis, sem estado de dados, sem semântica financeira e sem conhecimento de feature. `AppUI.Table` deve concentrar o shell visual; seleção, ordenação, filtros, `load()` e `refresh()` ficam fora. (`docs/design-system.md:43-52`, `docs/agents/design-system.md:36-40`, `docs/adr/0010-appui-como-fachada-de-primitives-visuais.md:25-33`)
- Semântica de tela: `Section`, agrupamento maior, fluxo e regras de formulário continuam na view chamadora. (`docs/design-system.md:48-52`, `docs/adr/0010-appui-como-fachada-de-primitives-visuais.md:31-33`, `docs/adr/0012-formularios-densos-com-form-nativo-em-sheet.md:29-31`, `docs/adr/0012-formularios-densos-com-form-nativo-em-sheet.md:57-58`)
- Semântica de domínio: categorias, instituições, contas, transações e faturas são conceitos do domínio financeiro do app; quando um componente recebe esses tipos diretamente, ele deixa de ser primitive pura. (`CONTEXT.md:17-27`, `CONTEXT.md:33-42`, `CONTEXT.md:50-52`, `CONTEXT.md:72-86`, `CONTEXT.md:90-107`)

## Findings Priorizados

### P0. `Shared/Components` ainda mistura primitives com componentes acoplados a domínio e serviço do app

O maior bloqueio para um módulo isolado de UI base não está mais nas forms ou tables principais; está no fato de que o diretório compartilhado ainda agrupa, lado a lado, a fachada `AppUI` e componentes que conhecem tipos de domínio ou infraestrutura do app. `AppUI` foi definido explicitamente como fachada de primitives visuais reutilizáveis. (`GranaApp/Shared/Components/AppUI.swift:1-4`, `docs/adr/0010-appui-como-fachada-de-primitives-visuais.md:20-30`)

No mesmo diretório, `CategoryBadge` recebe `Category` e `CategoryIcon`, decide tint a partir de `category.kind` e usa fallback semântico por tipo de categoria; `InstitutionIcon` recebe `InstitutionKind`; `TransactionRow` conhece `InstitutionKind`, status de importação e direção semântica de valor; `NoticeCard` recebe `NoticeCenter.Notice` e o mesmo arquivo estende `NoticeCenter.Kind` para mapear ícone e cor. Esses quatro componentes não são primitives puras, porque dependem diretamente de conceitos que o `CONTEXT.md` define como domínio financeiro ou de um serviço de feedback global do app. (`GranaApp/Shared/Components/CategoryBadge.swift:5-10`, `GranaApp/Shared/Components/CategoryBadge.swift:31-79`, `GranaApp/Shared/Components/InstitutionIcon.swift:16-18`, `GranaApp/Shared/Components/InstitutionIcon.swift:28-53`, `GranaApp/Shared/Components/TransactionRow.swift:15-18`, `GranaApp/Shared/Components/TransactionRow.swift:37-49`, `GranaApp/Shared/Components/NoticeOverlay.swift:42-50`, `GranaApp/Shared/Components/NoticeOverlay.swift:114-129`, `CONTEXT.md:17-27`, `CONTEXT.md:50-52`, `CONTEXT.md:72-86`)

Para viabilizar um módulo isolado só de UI base, a separação mínima é:

- `UIBase`: `GranaTheme`, `AppUI`, `AppUI.Field`, `AppUI.TextField`, `AppUI.Toggle`, `AppUI.DatePicker`, `AppUI.CurrencyField`, `AppUI.Selector`, `AppUI.Table`.
- Camada acima: `CategoryBadge`, `InstitutionIcon`, `TransactionRow`, `NoticeOverlay` e demais componentes que recebem tipos do domínio ou do app. (`GranaApp/Shared/Components/AppUIField.swift:3-81`, `GranaApp/Shared/Components/AppUITextField.swift:3-72`, `GranaApp/Shared/Components/AppUIToggle.swift:3-52`, `GranaApp/Shared/Components/AppUIDatePicker.swift:3-45`, `GranaApp/Shared/Components/AppUICurrencyField.swift:5-119`, `GranaApp/Shared/Components/AppUISelector.swift:3-171`, `GranaApp/Shared/Components/AppUITable.swift:3-43`)

### P0. O wizard de importação concentra primitives visuais reutilizáveis dentro de `Features/Import` e ainda cruza camadas

`ImportWizardStageScaffold`, `ImportWizardSplitLayout`, `ImportWizardSectionCard`, `ImportWizardMetricRow`, `ImportWizardInfoRow`, `ImportWizardBadge` e `ImportWizardBadgeView` são shells visuais compartilhados entre etapas, mas vivem em `GranaApp/Features/Import/ImportWizardComponents.swift` em vez de uma camada compartilhada. Isso já indica que a separação atual ainda está orientada por feature, não por primitive. (`GranaApp/Features/Import/ImportWizardComponents.swift:3-15`, `GranaApp/Features/Import/ImportWizardComponents.swift:34-60`, `GranaApp/Features/Import/ImportWizardComponents.swift:192-234`, `GranaApp/Features/Import/ImportWizardComponents.swift:236-269`, `GranaApp/Features/Import/ImportWizardComponents.swift:271-358`)

O acoplamento cruza ainda mais as camadas porque `ImportWizardTableStatusBadge` depende de `TransactionRow.Status`, um tipo definido em `Shared/Components/TransactionRow.swift` para outra família de apresentação. A mesma duplicação aparece na prática: `TransactionRow` já implementa um badge visual por `Status.Tint`, e o wizard reimplementa o mesmo badge em outro arquivo. (`GranaApp/Features/Import/ImportWizardComponents.swift:315-345`, `GranaApp/Shared/Components/TransactionRow.swift:18-27`, `GranaApp/Shared/Components/TransactionRow.swift:110-136`)

`TransactionsSelectionRow` também é compartilhada entre OFX e CSV, mas continua em `Features/Import/Components`, com shell visual próprio para uma barra de seleção recorrente. (`GranaApp/Features/Import/Components/TransactionsSelectionRow.swift:3-31`, `GranaApp/Features/Import/Steps/CSVReviewStepView.swift:168-174`, `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:222-240`)

Para extrair um módulo de primitives, o wizard precisa ser quebrado em duas partes:

- primitives base reaproveitáveis: scaffold/surface/status badge/selection summary row;
- semântica de importação: `ImportWizardStage`, rótulos de triagem/classificação/revisão e qualquer regra que dependa de extrato, lote ou revisão. (`CONTEXT.md:160-190`, `GranaApp/Features/Import/ImportWizardComponents.swift:17-32`)

### P1. Há shells visuais repetidos nas features que ainda não viraram primitive canônica

`AccountListView` ainda carrega um `panelHeader` completo com título, subtítulo, badge de contagem, fundo e divisor, além de um `AccountListFilterBar` que reaplica background e stroke manualmente sobre `AppUI.Toggle`. Isso significa que parte do shell de painel e da casca de filtros ainda está presa à feature, mesmo sendo visualmente reaproveitável. (`GranaApp/Features/Accounts/AccountListView.swift:10-18`, `GranaApp/Features/Accounts/AccountListView.swift:91-118`, `GranaApp/Features/Accounts/AccountListView.swift:121-163`)

`CategorizationReviewView` e `CategorizationRowView` repetem a mesma primitive local de label de menu tabelado: `HStack` com texto, ícone de sort, padding, fundo de `controlBackgroundColor` e `RoundedRectangle` com raio `6`. A diferença entre os dois arquivos é apenas o nome da função. (`GranaApp/Features/Categorization/CategorizationReviewView.swift:157-175`, `GranaApp/Features/Categorization/CategorizationReviewView.swift:226-240`, `GranaApp/Features/Categorization/CategorizationRowView.swift:52-71`, `GranaApp/Features/Categorization/CategorizationRowView.swift:118-130`)

O padrão normativo do repositório é que, quando uma tela precisar de primitive visual reutilizável, o consumo prefira `AppUI.*` em vez de instanciar ou estilizar `SwiftUI` localmente. Esses casos mostram que ainda faltam primitives canônicas para painel/cabeçalho interno, label de menu em tabela e shell de filtro com toggle. (`docs/design-system.md:43-52`, `docs/agents/design-system.md:32-40`)

### P1. A camada de `AppUI.Table` já centraliza a casca, mas as células continuam repetindo primitives de apresentação nas features

O contrato de `AppUI.Table` está correto: ele concentra superfície, clip e área de `filterBar`, enquanto dados e estado ficam fora. (`GranaApp/Shared/Components/AppUITable.swift:3-43`, `docs/design-system.md:48-52`)

O problema remanescente é que cada feature ainda recompõe manualmente as mesmas células visuais. `TransactionListView` renderiza instituição com ícone + título + subtítulo, categoria com `CategoryBadge` + texto, valor alinhado em formato contábil e ações de ícone. (`GranaApp/Features/Transactions/TransactionListView.swift:49-106`, `GranaApp/Features/Transactions/TransactionListView.swift:150-199`)

`CSVReviewStepView` e `OFXReviewStepView` repetem a mesma família visual de célula para data, descrição com `InstitutionIcon`, situação/badge, valor monetário e célula de seleção com `AppUI.Toggle`. (`GranaApp/Features/Import/Steps/CSVReviewStepView.swift:121-176`, `GranaApp/Features/Import/Steps/CSVReviewStepView.swift:178-265`, `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:167-243`, `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:252-285`)

`StatementListView` repete outra célula visual de categoria com `CategoryBadge`, placeholder visual e amount styling, enquanto `CategorizationReviewView` recompõe status, descrição com ícone e rótulo de menu inline. (`GranaApp/Features/CreditCards/Statements/StatementListView.swift:47-127`, `GranaApp/Features/Categorization/CategorizationReviewView.swift:59-113`)

Isso não exige mover semântica de negócio para `AppUI.Table`, mas exige introduzir primitives menores de célula e badge para não continuar espalhando shell visual em cada lista.

### P1. Há componentes híbridos cuja API ainda mistura dado semântico e visual de forma difícil de extrair

`CategoryBadge` recebe ao mesmo tempo o modelo `Category` inteiro e um `CategoryIcon?`; depois decide internamente se mostra nome, fallback semântico por `kind` e cor por `icon.color` ou por `category.kind`. A API hoje embute domínio e rendering na mesma primitive. (`GranaApp/Shared/Components/CategoryBadge.swift:5-10`, `GranaApp/Shared/Components/CategoryBadge.swift:31-79`)

`TransactionRow` faz algo parecido: recebe texto, data e amount, mas também incorpora `InstitutionKind`, direção semântica de valor, regra de dimming por duplicata e badge de status. Isso o torna um componente híbrido, não um bloco de UI base. (`GranaApp/Shared/Components/TransactionRow.swift:15-18`, `GranaApp/Shared/Components/TransactionRow.swift:41-49`, `GranaApp/Shared/Components/TransactionRow.swift:97-108`, `GranaApp/Shared/Components/TransactionRow.swift:110-136`)

`ImportWizardTableStatusBadge` e `CategoryIconBubble` mostram o mesmo padrão em escala menor: aparência reutilizável, mas API presa a um tipo semântico específico (`TransactionRow.Status` e `CategoryIcon`). (`GranaApp/Features/Import/ImportWizardComponents.swift:315-345`, `GranaApp/Features/CreditCards/Statements/StatementListView.swift:181-197`)

A quebra recomendada aqui é separar:

- visual tokenizado: texto, ícone, tint, background, radius;
- view-model semântico: adaptação de `Category`, `InstitutionKind`, `TransactionRow.Status` e similares para esses tokens. (`docs/design-system.md:73-98`, `docs/agents/design-system.md:5-18`)

### P2. Nem todo componente compartilhado atual deve entrar no módulo de primitives

O repositório já diferencia primitives de controles (`AppUI.*`) de shells maiores de tela e formulário. `AppUI.Form` concentra shell, header, footer de ações e mensagem de erro para formulários densos; o próprio ADR 0012 a descreve como casca estrutural compartilhada, não como primitive atômica. (`GranaApp/Shared/Components/AppUIForm.swift:3-126`, `docs/adr/0012-formularios-densos-com-form-nativo-em-sheet.md:24-31`, `docs/adr/0012-formularios-densos-com-form-nativo-em-sheet.md:45-46`)

O mesmo vale para `FeatureScreenHeader`, `BottomActionBar`, `EmptyStateView` e `AppNavigationRail`: são componentes compartilhados úteis, mas operam no nível de shell de tela, estado vazio e navegação autenticada, não no nível de UI base minimalista definido para `AppUI.*`. (`GranaApp/Shared/Components/FeatureScreenHeader.swift:3-57`, `GranaApp/Shared/Components/BottomActionBar.swift:3-28`, `GranaApp/Shared/Components/EmptyStateView.swift:10-145`, `GranaApp/App/AppNavigationRail.swift:3-61`, `docs/design-system.md:32-45`, `docs/design-system.md:56-65`, `docs/design-system.md:124-126`)

Isso não é um erro de implementação, mas é uma decisão de escopo que precisa ficar explícita antes da extração: um módulo “só de UI base/primitives” não deve absorver automaticamente todos os componentes compartilhados do app.

## Inventário de Separação Recomendado

### Pode formar o núcleo inicial de `UIBase`

- `GranaTheme` e tokens associados, porque são a fonte visual canônica do app. (`AGENTS.md:58-60`, `docs/design-system.md:73-120`)
- `AppUI` e seus wrappers de campo, seleção, data, moeda e tabela. (`docs/adr/0010-appui-como-fachada-de-primitives-visuais.md:20-30`, `GranaApp/Shared/Components/AppUI.swift:1-4`, `GranaApp/Shared/Components/AppUIField.swift:3-81`, `GranaApp/Shared/Components/AppUITable.swift:3-43`)

### Deve ficar fora de `UIBase` ou subir para uma camada semântica acima

- shells de tela e formulário: `FeatureScreenHeader`, `BottomActionBar`, `AppUI.Form`, `EmptyStateView`, `AppNavigationRail`. (`GranaApp/Shared/Components/AppUIForm.swift:3-126`, `GranaApp/Shared/Components/FeatureScreenHeader.swift:3-57`, `GranaApp/Shared/Components/BottomActionBar.swift:3-28`, `GranaApp/Shared/Components/EmptyStateView.swift:10-145`, `GranaApp/App/AppNavigationRail.swift:3-61`)
- componentes acoplados a domínio/app: `CategoryBadge`, `InstitutionIcon`, `TransactionRow`, `NoticeOverlay`. (`GranaApp/Shared/Components/CategoryBadge.swift:5-79`, `GranaApp/Shared/Components/InstitutionIcon.swift:16-53`, `GranaApp/Shared/Components/TransactionRow.swift:15-149`, `GranaApp/Shared/Components/NoticeOverlay.swift:12-147`)
- scaffolds visuais hoje presos ao wizard de importação. (`GranaApp/Features/Import/ImportWizardComponents.swift:3-358`, `GranaApp/Features/Import/Components/TransactionsSelectionRow.swift:3-31`)

## Próximos passos sugeridos

1. Criar a fronteira física primeiro: `UIBase` só com tema e `AppUI.*`; mover o restante para um namespace ou target acima, em vez de começar pelos componentes mais híbridos.
2. Extrair primitives faltantes que hoje aparecem repetidas: `StatusBadge`, `TableMenuLabel`, `SelectionSummaryBar`, `PanelHeader` e blocos de célula para tabela.
3. Só depois adaptar `CategoryBadge`, `InstitutionIcon`, `TransactionRow` e o wizard para view-models semânticos sobre essas primitives menores.

## Arquivos alterados

- `docs/ui-base-primitives-separation-audit-2026-08-30.md`
