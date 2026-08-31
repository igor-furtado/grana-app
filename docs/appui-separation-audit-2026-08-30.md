# Auditoria de Separação para Módulo de UI Base

Data: 2026-08-30

## Escopo e método

Esta auditoria cobre a camada SwiftUI do repositório com o objetivo específico de identificar o que ainda precisa ser separado para viabilizar um módulo isolado de UI base e primitives. As fontes usadas foram apenas primárias locais: `AGENTS.md`, `docs/design-system.md`, `docs/adr/0010-appui-como-fachada-de-primitives-visuais.md` e o código em `GranaApp/Features` e `GranaApp/Shared/Components`. O critério aplicado foi: `view` de feature mantém fluxo, estado, bindings e semântica de negócio; primitive de UI base concentra shell visual, slots e API genérica, sem depender de tipos de domínio nem de stores. (Fontes: `AGENTS.md:31-49`, `AGENTS.md:76-82`, `docs/design-system.md:43-52`, `docs/adr/0010-appui-como-fachada-de-primitives-visuais.md:20-33`)

O repositório já avançou na direção correta com `AppUI` como fachada canônica e com a nova família `AppUI.Form`. Isso mostra que a separação já começou, mas ainda está incompleta e desigual entre features. (Fontes: `docs/adr/0010-appui-como-fachada-de-primitives-visuais.md:20-33`, `GranaApp/Shared/Components/AppUIForm.swift:3-126`)

## Leitura objetiva do estado atual

Hoje existem três classes distintas de componente:

1. primitives já encaminhadas para uma base de UI, como `AppUI.Table`, `AppUI.TextField`, `AppUI.Toggle`, `AppUI.DatePicker`, `AppUI.CurrencyField`, `AppUI.Selector` e agora `AppUI.Form.*`; (Fontes: `docs/design-system.md:43-52`, `GranaApp/Shared/Components/AppUIForm.swift:7-126`)
2. componentes visualmente genéricos que ainda moram dentro de `Features`, o que impede um módulo de UI base realmente isolado; (Fontes: `GranaApp/Features/Import/ImportWizardComponents.swift:3-358`, `GranaApp/Features/Import/Components/TransactionsSelectionRow.swift:3-31`, `GranaApp/Features/Accounts/AccountListView.swift:121-163`, `GranaApp/Features/Import/ImportHistoryView.swift:264-343`)
3. componentes em `Shared/Components` que são reutilizáveis no app, mas ainda carregam semântica de domínio e portanto não pertencem a um módulo de primitives puras. (Fontes: `GranaApp/Shared/Components/TransactionRow.swift:3-150`, `GranaApp/Shared/Components/InstitutionIcon.swift:4-54`, `GranaApp/Shared/Components/CategoryBadge.swift:3-80`, `GranaApp/Shared/Components/EmptyStateView.swift:10-145`)

## Findings priorizados

### P1. A infraestrutura visual do wizard de importação ainda está presa à feature

`ImportWizardStageScaffold`, `ImportWizardSplitLayout`, `ImportWizardSectionCard`, `ImportWizardMetricRow`, `ImportWizardInfoRow` e `ImportWizardBadgeView` formam uma mini biblioteca de layout e apresentação. Eles não coordenam importação; coordenam shell, card, sidebar de etapas e badges. Mesmo assim continuam em `GranaApp/Features/Import/ImportWizardComponents.swift`. Para um módulo de UI base, isso precisa sair de `Features`. (Fontes: `GranaApp/Features/Import/ImportWizardComponents.swift:3-15`, `GranaApp/Features/Import/ImportWizardComponents.swift:34-92`, `GranaApp/Features/Import/ImportWizardComponents.swift:192-358`)

O único pedaço que não deve ir para primitives puras sem ajuste é `ImportWizardStage`, porque os casos `.triage`, `.classification` e `.review` são semântica de fluxo de importação, não linguagem visual. A separação correta é extrair o shell visual e deixar o enum de etapa no domínio da feature, passando apenas estado/labels para a primitive. (Fontes: `GranaApp/Features/Import/ImportWizardComponents.swift:17-32`, `AGENTS.md:41-48`)

### P1. `TransactionsSelectionRow` já provou ser compartilhado, mas continua na feature de importação

O próprio comentário diz que a view é compartilhada entre OFX e CSV, e ela só resolve UI de seleção em massa: checkbox, resumo e fundo discreto. Isso é shared UI; não é lógica de importação. Enquanto ficar em `GranaApp/Features/Import/Components`, o módulo de base continua vazando feature. (Fontes: `GranaApp/Features/Import/Components/TransactionsSelectionRow.swift:3-31`, `GranaApp/Features/Import/Steps/CSVReviewStepView.swift:168-174`, `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:222-240`)

### P1. A família de filter bars ainda está montada ad hoc em cada tela

`AccountListFilterBar`, `TransactionsFilterBar` e `ImportHistoryFilterBar` repetem o mesmo padrão estrutural: composição de `AppUI.Selector` e `AppUI.TextField` dentro de um container horizontal, com o estado e bindings vindos da tela. O design system diz que a feature mantém semântica e filtros, mas os controles `AppUI.*` centralizam o shell visual; hoje falta justamente o shell de “filter bar” como primitive adicional. (Fontes: `docs/design-system.md:48-52`, `GranaApp/Features/Accounts/AccountListView.swift:121-163`, `GranaApp/Features/Transactions/TransactionListView.swift:263-375`, `GranaApp/Features/Import/ImportHistoryView.swift:264-303`)

O caso de `AccountListFilterBar` é ainda mais explícito: a view precisa redesenhar manualmente o shell do toggle com `background`, `overlay`, `frame(height: 40)` e `cornerRadius: 14` porque `AppUI.Toggle` ainda não cobre essa variante. Isso indica primitive faltante, não uma decisão de feature. (Fonte: `GranaApp/Features/Accounts/AccountListView.swift:145-160`)

### P1. Existem cards de seleção genéricos em duplicidade entre CSV e OFX

`CSVAccountInfoCard` e `OFXAccountInfoCard` repetem o mesmo problema visual: card com título “Conta de destino” e um `AppUI.Selector` no trailing. A variante OFX injeta metadados extras abaixo, mas o shell estrutural é o mesmo. Isso sugere um componente base com slots para título, trailing e conteúdo opcional, ou a generalização de `ImportWizardSectionCard` para fora da feature. (Fontes: `GranaApp/Features/Import/Steps/CSVReviewStepView.swift:45-66`, `GranaApp/Features/Import/Steps/OFXReviewStepView.swift:69-112`, `GranaApp/Features/Import/ImportWizardComponents.swift:192-233`)

### P1. O medidor de utilização ainda está duplicado em duas features de cartão

`CreditCardUsageBar` e `LimitGaugeBlock` implementam a mesma primitive de progressão de limite com percentuais, cor de faixa e preenchimento horizontal. Um está na seleção horizontal de cartões; o outro, no detalhe da fatura. A semântica “limite de crédito” é de produto, mas a barra/medidor em si é UI base o suficiente para sair da feature. (Fontes: `GranaApp/Features/CreditCards/CreditCardListView.swift:76-81`, `GranaApp/Features/CreditCards/CreditCardListView.swift:136-166`, `GranaApp/Features/CreditCards/Statements/CreditCardStatementsView.swift:140-218`)

### P2. `FeatureScreenHeader` está shared, mas fora da fachada `AppUI`

O header já é um shell visual canônico de tela principal, alinhado ao design system para substituir a toolbar nativa. Ele é suficientemente estrutural para morar no módulo de UI base, mas hoje continua como componente solto em `Shared/Components` e não dentro da entrada oficial `AppUI.*`. Se a meta é um módulo separado de primitives, esse header precisa ou virar `AppUI.ScreenHeader` ou ficar claramente em uma camada de shell UI distinta do resto do app. (Fontes: `docs/design-system.md:61-65`, `GranaApp/Shared/Components/FeatureScreenHeader.swift:3-58`)

### P2. `EmptyStateView` ainda depende de `AppIcon`, o que prende a primitive ao app

`EmptyStateView` é visualmente genérico e já substitui `ContentUnavailableView`, mas sua API recebe `AppIcon`, um tipo específico do app. Isso reduz a portabilidade do componente para um módulo de UI base. Se a intenção é separar primitives, a API precisa aceitar um símbolo, imagem ou slot genérico, deixando `AppIcon` na borda do app. (Fontes: `GranaApp/Shared/Components/EmptyStateView.swift:10-30`, `GranaApp/Shared/Components/EmptyStateView.swift:75-95`)

### P2. `TransactionRow` não deve entrar no módulo de primitives no formato atual

Apesar de estar em `Shared/Components`, `TransactionRow` carrega semântica financeira explícita: `AmountKind`, `Status.duplicate`, cor para receita/transferência, formatação monetária em `pt_BR` e dependência de `InstitutionKind`. Isso é shared UI do produto, não primitive base. Se o objetivo é um módulo de UI base puro, `TransactionRow` deve ficar fora dele ou ser quebrado em partes menores, como badge de status, célula monetária e avatar genérico. (Fontes: `GranaApp/Shared/Components/TransactionRow.swift:3-39`, `GranaApp/Shared/Components/TransactionRow.swift:41-150`)

### P2. `InstitutionIcon` e `CategoryBadge` também são shared do domínio, não primitives puras

`InstitutionIcon` depende diretamente de `InstitutionKind` e do catálogo de assets do app. `CategoryBadge` depende de `Category`, `CategoryIcon` e regras semânticas de categoria financeira. Ambos são componentes reaproveitáveis dentro do GranaApp, mas não pertencem a um módulo de base visual genérica sem antes trocar essas dependências por contratos neutros. (Fontes: `GranaApp/Shared/Components/InstitutionIcon.swift:4-54`, `GranaApp/Shared/Components/CategoryBadge.swift:3-80`)

### P3. Ainda há shells tabelares locais que misturam composição de feature com visual reaproveitável

`AccountListView`, `TransactionListView` e `ImportHistoryView` já usam `AppUI.Table`, mas cada uma ainda monta localmente partes visuais recorrentes como header de painel, action cells e colunas com avatar + título + subtítulo. Nem tudo aqui deve virar primitive, porque parte disso é semântica de tela; mas há matéria-prima para primitives menores como `InlineIconActions`, `TableIdentityCell` e `TableMetricCell`. Hoje essas estruturas continuam embutidas nas views principais. (Fontes: `GranaApp/Features/Accounts/AccountListView.swift:10-118`, `GranaApp/Features/Transactions/TransactionListView.swift:33-199`, `GranaApp/Features/Import/ImportHistoryView.swift:175-262`)

## O que eu separaria primeiro

Sequência recomendada:

1. Promover para a camada de UI compartilhada o que já é visualmente genérico e já está repetido: `ImportWizardStageScaffold`, `ImportWizardSplitLayout`, `ImportWizardSectionCard`, `ImportWizardMetricRow`, `ImportWizardInfoRow`, `ImportWizardBadgeView` e `TransactionsSelectionRow`. (Fontes: `GranaApp/Features/Import/ImportWizardComponents.swift:3-358`, `GranaApp/Features/Import/Components/TransactionsSelectionRow.swift:3-31`)
2. Criar novas primitives de composição, não de domínio: `AppUI.FilterBar`, variante de `AppUI.Toggle` para filtro compacto e um card genérico com header/trailing/content. (Fontes: `GranaApp/Features/Accounts/AccountListView.swift:121-163`, `GranaApp/Features/Transactions/TransactionListView.swift:263-375`, `GranaApp/Features/Import/ImportHistoryView.swift:264-303`)
3. Definir explicitamente o que fica fora do módulo de base: `TransactionRow`, `InstitutionIcon`, `CategoryBadge` e qualquer componente que receba `Transaction`, `Category`, `InstitutionKind`, `AppIcon` ou equivalentes sem camada de abstração. (Fontes: `GranaApp/Shared/Components/TransactionRow.swift:3-150`, `GranaApp/Shared/Components/InstitutionIcon.swift:4-54`, `GranaApp/Shared/Components/CategoryBadge.swift:3-80`, `GranaApp/Shared/Components/EmptyStateView.swift:10-30`)

## Conclusão curta

O principal gap não é falta de wrappers individuais; isso o repo já começou a resolver com `AppUI`. O que ainda falta separar é a camada intermediária de composição visual reutilizável: scaffolds, filter bars, cards com slots e medidores. Em paralelo, também falta podar do futuro módulo de UI base os componentes que parecem genéricos, mas ainda conhecem demais o domínio financeiro do app.
