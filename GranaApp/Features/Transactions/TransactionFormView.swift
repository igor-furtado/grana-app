import ComposableArchitecture
import SwiftUI

struct TransactionFormView: View {
    @Bindable var store: StoreOf<TransactionFormFeature>
    @FocusState private var focusedField: Field?
    #if DEBUG
        @State private var prototypeVariant: TransactionFormPrototypeVariant = .cards
    #endif

    var body: some View {
        ZStack(alignment: .bottom) {
            mainLayout

            if store.showsDiscardConfirmation {
                TransactionFormConfirmationOverlay(
                    icon: AppIcon.warning.systemImage,
                    tint: GranaTheme.Palette.amber,
                    title: "Descartar alterações?",
                    message: "As mudanças desta transação serão perdidas.",
                    cancelTitle: "Continuar editando",
                    confirmTitle: "Descartar",
                    confirmStyle: .destructive,
                    onCancel: { store.send(.discardChangesDismissed) },
                    onConfirm: { store.send(.discardChangesConfirmed) }
                )
            } else if store.showsRetroactivePreview {
                TransactionFormConfirmationOverlay(
                    icon: AppIcon.invalidDate.systemImage,
                    tint: GranaTheme.Palette.amber,
                    title: "Prévia do recálculo",
                    message: store.state.retroactivePreviewText,
                    cancelTitle: "Cancelar",
                    confirmTitle: "Confirmar alteração",
                    confirmStyle: .primary,
                    onCancel: { store.send(.retroactivePreviewCancelTapped) },
                    onConfirm: { store.send(.retroactivePreviewConfirmTapped) }
                )
            }

            #if DEBUG
                if !store.showsDiscardConfirmation, !store.showsRetroactivePreview {
                    TransactionFormPrototypeSwitcher(
                        variant: $prototypeVariant,
                        snapshot: prototypeSnapshot,
                        onPrevious: showPreviousPrototypeVariant,
                        onNext: showNextPrototypeVariant
                    )
                    .padding(.horizontal, GranaTheme.Spacing.lg)
                    .padding(.bottom, GranaTheme.Spacing.lg)
                    .transition(.opacity)
                }
            #endif
        }
        .toolbar(.hidden, for: .windowToolbar)
        .onAppear {
            if !store.isEditing {
                focusedField = .description
            }
        }
        .onExitCommand {
            store.send(.cancelButtonTapped)
        }
    }

    private var mainLayout: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            header
            Divider()
                .overlay(GranaTheme.Palette.line)
            activeFormContent
            Divider()
                .overlay(GranaTheme.Palette.line)
            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if DEBUG
            .padding(.bottom, 88)
        #endif
    }

    private var header: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                Text(store.title)
                    .font(GranaTheme.Typography.title3)
                    .foregroundStyle(GranaTheme.Palette.ink)

                if let subtitle = store.subtitle {
                    Text(subtitle)
                        .font(GranaTheme.Typography.subheadline)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: GranaTheme.Spacing.none)

            Button {
                store.send(.cancelButtonTapped)
            } label: {
                Image(systemName: AppIcon.close.systemImage)
                    .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .padding(GranaTheme.Spacing.xs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(store.isSaving)
            .help("Fechar")
            .accessibilityLabel("Fechar formulário")
        }
        .padding(GranaTheme.Spacing.lg)
    }

    @ViewBuilder
    private var activeFormContent: some View {
        #if DEBUG
            switch prototypeVariant {
            case .cards:
                prototypeCardsContent
            case .unified:
                prototypeUnifiedContent
            case .compact:
                prototypeCompactContent
            }
        #else
            defaultFormContent
        #endif
    }

    private var defaultFormContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                essentialSection
                classificationSection

                let showsRefundSection = store.supportsAdvancedCardRules
                    && store.selectedAccountIsCreditCard
                    && store.selectedCategoryKind != .transfer
                if showsRefundSection {
                    refundSection
                }

                if store.supportsAdvancedCardRules, store.isPayingCreditCard {
                    statementPaymentSection
                }

                timingSection
                notesSection
            }
            .padding(GranaTheme.Spacing.lg)
        }
        .scrollIndicators(.visible)
    }

    private var prototypeCardsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                prototypeAssumptionBanner
                TransactionFormPrototypePromptCard(
                    title: "Variante A",
                    message: "Cards independentes por decisão: o preenchimento começa pelo essencial e cada escolha seguinte vive em seu próprio bloco."
                )
                prototypeDescriptionAmountCard
                prototypeAccountSelectorCard
                prototypeCategorySelectorCard

                if showsRefundSection {
                    prototypeRefundCard
                }

                if showsStatementPaymentSection {
                    prototypeStatementPaymentCard
                }

                prototypeDateTimeCard
                prototypeNotesCard
                prototypeLiveSummaryCard
            }
            .padding(GranaTheme.Spacing.lg)
        }
        .scrollIndicators(.visible)
    }

    private var prototypeUnifiedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                prototypeAssumptionBanner
                TransactionFormPrototypePromptCard(
                    title: "Variante B",
                    message: "Tudo junto em uma única superfície, sem seções formais, para testar se o fluxo contínuo reduz fricção."
                )

                prototypeUnifiedCanvas

                if showsRefundSection {
                    prototypeRefundCard
                }

                if showsStatementPaymentSection {
                    prototypeStatementPaymentCard
                }

                prototypeLiveSummaryCard
            }
            .padding(GranaTheme.Spacing.lg)
        }
        .scrollIndicators(.visible)
    }

    private var prototypeCompactContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                prototypeAssumptionBanner
                TransactionFormPrototypePromptCard(
                    title: "Variante C",
                    message: "Blocos compactos em grade, com menos altura e mais campos visíveis ao mesmo tempo dentro do drawer."
                )

                prototypeCompactTopGrid
                prototypeCompactSelectorGrid

                if showsRefundSection {
                    prototypeRefundCard
                }

                if showsStatementPaymentSection {
                    prototypeStatementPaymentCard
                }

                prototypeCompactDateGrid
                prototypeNotesCard
                prototypeLiveSummaryCard
            }
            .padding(GranaTheme.Spacing.lg)
        }
        .scrollIndicators(.visible)
    }

    private var essentialSection: some View {
        TransactionFormSection(title: "Essencial") {
            TransactionFormFieldGroup {
                descriptionRow

                TransactionFormDivider()

                amountRow
            }
        }
    }

    private var classificationSection: some View {
        TransactionFormSection(title: "Classificação") {
            TransactionFormFieldGroup {
                accountRow

                TransactionFormDivider()

                categoryRow

                if showsSubcategoryRow {
                    TransactionFormDivider()
                    subcategoryRow
                }

                if showsDestinationAccountRow {
                    TransactionFormDivider()
                    destinationAccountRow
                }
            }
        }
    }

    private var statementPaymentSection: some View {
        TransactionFormSection(
            title: "Pagamento de fatura",
            footer: "O valor será aplicado às dívidas elegíveis mais antigas. Excesso sobre uma fatura paga fica visível como pagamento excedente."
        ) {
            TransactionFormFieldGroup {
                if store.state.automaticPaymentPreview.isEmpty {
                    TransactionFormEmptyRow("Nenhuma dívida elegível nessa data.")
                } else {
                    ForEach(
                        Array(store.state.automaticPaymentPreview.enumerated()),
                        id: \.element.statement.id
                    ) { index, item in
                        if index > 0 {
                            TransactionFormDivider()
                        }
                        TransactionFormRow(title: statementPickerLabel(item.statement)) {
                            Text(item.amount.formatted(.currency(code: "BRL")))
                                .font(GranaTheme.Typography.moneySubheadline)
                                .foregroundStyle(GranaTheme.Palette.ink)
                        }
                    }
                }
            }
        }
    }

    private var refundSection: some View {
        TransactionFormSection(
            title: "Cartão",
            footer: "Estornos herdam conta e categoria da compra e pertencem ao ciclo da própria data."
        ) {
            TransactionFormFieldGroup {
                TransactionFormRow(title: "Estorno de") {
                    Picker("", selection: $store.refundOfTransactionId) {
                        Text("Não é estorno").tag(UUID?.none)
                        ForEach(store.state.refundablePurchases) { purchase in
                            Text(
                                "\(purchase.description) · \(store.state.remainingRefundableAmount(for: purchase).formatted(.currency(code: "BRL")))"
                            )
                            .tag(UUID?.some(purchase.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 250, alignment: .trailing)
                }
            }
        }
    }

    private var timingSection: some View {
        TransactionFormSection(title: "Quando") {
            TransactionFormFieldGroup {
                dateRow

                TransactionFormDivider()

                timeRow
            }
        }
    }

    private var notesSection: some View {
        TransactionFormSection(title: "Notas") {
            ZStack(alignment: .topLeading) {
                if store.notes.isEmpty {
                    Text("Opcional")
                        .font(GranaTheme.Typography.callout)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .padding(GranaTheme.Spacing.md)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $store.notes)
                    .font(GranaTheme.Typography.body)
                    .foregroundStyle(GranaTheme.Palette.ink)
                    .frame(minHeight: 110, maxHeight: 180)
                    .scrollContentBackground(.hidden)
                    .padding(GranaTheme.Spacing.sm)
            }
            .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
        }
    }

    private var actions: some View {
        BottomActionBar {
            Button("Cancelar") {
                store.send(.cancelButtonTapped)
            }
            .buttonStyle(GranaSecondaryButtonStyle())
            .disabled(store.isSaving)

            Button {
                store.send(.saveButtonTapped)
            } label: {
                HStack(spacing: GranaTheme.Spacing.xs) {
                    if store.isSaving {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(store.isSaving ? "Salvando..." : store.saveButtonTitle)
                }
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(!store.canSave || store.isSaving)
        }
        .padding(.horizontal, GranaTheme.Spacing.lg)
    }

    private var descriptionRow: some View {
        TransactionFormRow(title: "Descrição") {
            TextField("Descrição", text: $store.description, prompt: Text("Ex: Almoço no restaurante"))
                .textFieldStyle(.plain)
                .font(GranaTheme.Typography.bodyEmphasis)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .description)
        }
    }

    private var amountRow: some View {
        TransactionFormRow(title: "Valor") {
            CurrencyField(cents: $store.amountCents)
                .font(GranaTheme.Typography.moneyTitle3)
                .frame(maxWidth: 180, alignment: .trailing)
        }
    }

    private var accountRow: some View {
        TransactionFormRow(title: "Conta") {
            Picker("", selection: $store.accountId) {
                ForEach(store.state.sourceAccountOptions) { account in
                    Text(store.state.displayName(for: account)).tag(UUID?.some(account.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 250, alignment: .trailing)
        }
    }

    private var categoryRow: some View {
        TransactionFormRow(title: "Categoria") {
            Picker("", selection: $store.categoryId) {
                ForEach(store.state.rootCategories) { category in
                    Text(category.name).tag(UUID?.some(category.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 250, alignment: .trailing)
        }
    }

    private var subcategoryRow: some View {
        TransactionFormRow(title: "Subcategoria") {
            Picker("", selection: $store.subcategoryId) {
                Text("(nenhuma)").tag(UUID?.none)
                ForEach(selectedSubcategories) { subcategory in
                    Text(subcategory.name).tag(UUID?.some(subcategory.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 250, alignment: .trailing)
        }
    }

    private var destinationAccountRow: some View {
        TransactionFormRow(title: "Conta de destino") {
            Picker("", selection: $store.destinationAccountId) {
                Text("(nenhuma)").tag(UUID?.none)
                ForEach(store.state.destinationAccountOptions) { account in
                    Text(store.state.displayName(for: account)).tag(UUID?.some(account.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 250, alignment: .trailing)
        }
    }

    private var dateRow: some View {
        TransactionFormRow(title: "Data") {
            DatePicker("", selection: $store.occurredAt, displayedComponents: [.date])
                .labelsHidden()
                .frame(maxWidth: 180, alignment: .trailing)
        }
    }

    private var timeRow: some View {
        TransactionFormRow(title: "Hora") {
            DatePicker("", selection: $store.occurredAt, displayedComponents: [.hourAndMinute])
                .labelsHidden()
                .frame(maxWidth: 180, alignment: .trailing)
        }
    }

    private var selectedSubcategories: [Category] {
        guard let categoryId = store.categoryId else { return [] }
        return store.state.subcategories(of: categoryId)
    }

    private var showsSubcategoryRow: Bool {
        !selectedSubcategories.isEmpty
    }

    private var showsDestinationAccountRow: Bool {
        store.selectedCategoryKind == .transfer
    }

    private var showsRefundSection: Bool {
        store.supportsAdvancedCardRules
            && store.selectedAccountIsCreditCard
            && store.selectedCategoryKind != .transfer
    }

    private var showsStatementPaymentSection: Bool {
        store.supportsAdvancedCardRules && store.isPayingCreditCard
    }

    private func statementPickerLabel(_ statement: Statement) -> String {
        let monthYear = Self.statementMonthFormatter.string(from: statement.dueDate)
        let remaining = store.state.remainingAmount(of: statement)
        let total = statement.totalAmount
        let remainingStr = remaining.formatted(.currency(code: "BRL"))
        let totalStr = total.formatted(.currency(code: "BRL"))
        return "Fatura \(monthYear) · faltam \(remainingStr) de \(totalStr)"
    }

    private enum Field: Hashable {
        case description
    }

    private static let statementMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM/yyyy"
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    #if DEBUG
        private var prototypeAssumptionBanner: some View {
            TransactionFormPrototypeAssumptionBanner()
        }

        private var prototypeLiveSummaryCard: some View {
            TransactionFormPrototypeLiveSummaryCard(data: prototypeDecorationData)
        }

        private var prototypeDescriptionAmountCard: some View {
            TransactionFormPrototypeCard(title: "O que aconteceu?") {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                    prototypeDescriptionField
                    prototypeAmountField
                }
            }
        }

        private var prototypeAccountSelectorCard: some View {
            TransactionFormPrototypeCard(title: "Qual conta?") {
                prototypeAccountSelector
            }
        }

        private var prototypeCategorySelectorCard: some View {
            TransactionFormPrototypeCard(title: "Como classificar?") {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                    prototypeCategorySelector

                    if showsSubcategoryRow {
                        prototypeSubcategorySelector
                    }

                    if showsDestinationAccountRow {
                        prototypeDestinationSelector
                    }
                }
            }
        }

        private var prototypeDateTimeCard: some View {
            TransactionFormPrototypeCard(title: "Quando aconteceu?") {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                    prototypeDateSelector
                    prototypeTimeSelector
                }
            }
        }

        private var prototypeNotesCard: some View {
            TransactionFormPrototypeCard(title: "Notas") {
                prototypeNotesField
            }
        }

        private var prototypeRefundCard: some View {
            TransactionFormPrototypeCard(
                title: "Estorno",
                subtitle: "Seleção visual da compra de origem."
            ) {
                prototypeRefundSelector
            }
        }

        private var prototypeStatementPaymentCard: some View {
            TransactionFormPrototypeCard(
                title: "Pagamento de fatura",
                subtitle: "Prévia das faturas impactadas."
            ) {
                prototypeStatementPaymentSummary
            }
        }

        private var prototypeUnifiedCanvas: some View {
            TransactionFormPrototypeCard(
                title: "Preencher transação",
                subtitle: "Sem seções explícitas; os controles visuais criam a hierarquia."
            ) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                    prototypeDescriptionField
                    prototypeAmountField
                    prototypeAccountSelector
                    prototypeCategorySelector

                    if showsSubcategoryRow {
                        prototypeSubcategorySelector
                    }

                    if showsDestinationAccountRow {
                        prototypeDestinationSelector
                    }

                    prototypeDateSelector
                    prototypeTimeSelector
                    prototypeNotesField
                }
            }
        }

        private var prototypeCompactTopGrid: some View {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                prototypeCompactDescriptionCard
                prototypeCompactAmountCard
            }
        }

        private var prototypeCompactSelectorGrid: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                    TransactionFormPrototypeCard(title: "Conta") {
                        prototypeAccountSelector
                    }
                    TransactionFormPrototypeCard(title: "Categoria") {
                        prototypeCategorySelector
                    }
                }

                if showsSubcategoryRow || showsDestinationAccountRow {
                    HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                        if showsSubcategoryRow {
                            TransactionFormPrototypeCard(title: "Subcategoria") {
                                prototypeSubcategorySelector
                            }
                        }

                        if showsDestinationAccountRow {
                            TransactionFormPrototypeCard(title: "Destino") {
                                prototypeDestinationSelector
                            }
                        }
                    }
                }
            }
        }

        private var prototypeCompactDateGrid: some View {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                TransactionFormPrototypeCard(title: "Data") {
                    prototypeDateSelector
                }
                TransactionFormPrototypeCard(title: "Hora") {
                    prototypeTimeSelector
                }
            }
        }

        private var prototypeCompactDescriptionCard: some View {
            TransactionFormPrototypeCard(title: "Descrição") {
                prototypeDescriptionField
            }
            .frame(maxWidth: .infinity)
        }

        private var prototypeCompactAmountCard: some View {
            TransactionFormPrototypeCard(title: "Valor") {
                prototypeAmountField
            }
            .frame(width: 180)
        }

        private var prototypeDescriptionField: some View {
            TransactionFormPrototypeTextField(
                title: "Descrição",
                placeholder: "Ex: almoço no restaurante",
                text: $store.description
            )
        }

        private var prototypeAmountField: some View {
            TransactionFormPrototypeCurrencyField(
                title: "Valor",
                cents: $store.amountCents
            )
        }

        private var prototypeAccountSelector: some View {
            TransactionFormPrototypeOptionSelector(
                title: "Conta",
                subtitle: "Toque uma opção",
                options: accountOptions,
                selection: $store.accountId
            )
        }

        private var prototypeCategorySelector: some View {
            TransactionFormPrototypeOptionSelector(
                title: "Categoria",
                subtitle: "Escolha o tipo principal",
                options: categoryOptions,
                selection: $store.categoryId
            )
        }

        private var prototypeSubcategorySelector: some View {
            TransactionFormPrototypeOptionSelector(
                title: "Subcategoria",
                subtitle: "Opcional",
                options: subcategoryOptions,
                selection: $store.subcategoryId,
                includesNoneOption: true,
                noneOptionTitle: "Sem subcategoria"
            )
        }

        private var prototypeDestinationSelector: some View {
            TransactionFormPrototypeOptionSelector(
                title: "Conta de destino",
                subtitle: "Obrigatório para transferência",
                options: destinationAccountOptions,
                selection: $store.destinationAccountId,
                includesNoneOption: true,
                noneOptionTitle: "Selecionar depois"
            )
        }

        private var prototypeRefundSelector: some View {
            TransactionFormPrototypeOptionSelector(
                title: "Compra original",
                subtitle: "Origem do estorno",
                options: refundablePurchaseOptions,
                selection: $store.refundOfTransactionId,
                includesNoneOption: true,
                noneOptionTitle: "Não é estorno"
            )
        }

        private var prototypeDateSelector: some View {
            TransactionFormPrototypeDateSelector(
                selection: $store.occurredAt,
                calendar: .current,
                quickActions: [
                    .init(title: "Hoje", action: { setPrototypeDate(dayOffset: 0) }),
                    .init(title: "Ontem", action: { setPrototypeDate(dayOffset: -1) }),
                    .init(title: "7 dias", action: { setPrototypeDate(dayOffset: -7) }),
                ]
            )
        }

        private var prototypeTimeSelector: some View {
            TransactionFormPrototypeTimeSelector(
                selection: $store.occurredAt,
                quickActions: [
                    .init(title: "08:00", action: { setPrototypeTime(hour: 8, minute: 0) }),
                    .init(title: "12:00", action: { setPrototypeTime(hour: 12, minute: 0) }),
                    .init(title: "19:30", action: { setPrototypeTime(hour: 19, minute: 30) }),
                ]
            )
        }

        private var prototypeNotesField: some View {
            TransactionFormPrototypeNotesField(text: $store.notes)
        }

        private var prototypeStatementPaymentSummary: some View {
            TransactionFormPrototypeStatementSummary(items: prototypeStatementItems)
        }

        private var accountOptions: [TransactionFormPrototypeOption<UUID>] {
            store.state.sourceAccountOptions.map { account in
                .init(
                    id: account.id,
                    title: store.state.displayName(for: account),
                    badge: account.type == .creditCard ? "Cartão" : "Conta"
                )
            }
        }

        private var categoryOptions: [TransactionFormPrototypeOption<UUID>] {
            store.state.rootCategories.map { category in
                .init(
                    id: category.id,
                    title: category.name,
                    badge: category.kind.displayName
                )
            }
        }

        private var subcategoryOptions: [TransactionFormPrototypeOption<UUID>] {
            selectedSubcategories.map { category in
                .init(id: category.id, title: category.name)
            }
        }

        private var destinationAccountOptions: [TransactionFormPrototypeOption<UUID>] {
            store.state.destinationAccountOptions.map { account in
                .init(
                    id: account.id,
                    title: store.state.displayName(for: account),
                    badge: account.type == .creditCard ? "Cartão" : "Conta"
                )
            }
        }

        private var refundablePurchaseOptions: [TransactionFormPrototypeOption<UUID>] {
            store.state.refundablePurchases.map { purchase in
                .init(
                    id: purchase.id,
                    title: purchase.description,
                    badge: store.state.remainingRefundableAmount(for: purchase).formatted(.currency(code: "BRL"))
                )
            }
        }

        private var prototypeStatementItems: [TransactionFormPrototypeStatementItem] {
            if store.state.automaticPaymentPreview.isEmpty {
                return [.empty(message: "Nenhuma dívida elegível nessa data.")]
            }

            return store.state.automaticPaymentPreview.map { item in
                .filled(
                    title: statementPickerLabel(item.statement),
                    value: item.amount.formatted(.currency(code: "BRL"))
                )
            }
        }

        private var prototypeSnapshot: TransactionFormPrototypeSnapshot {
            TransactionFormPrototypeSnapshot(
                title: prototypeVariant.displayTitle,
                summary: "\(store.isEditing ? "Edição" : "Nova") · \(prototypeKindLabel) · \(store.amount.formatted(.currency(code: "BRL")))",
                details: "\(prototypeAccountName) · \(prototypeCategoryName) · \(store.canSave ? "pronto para salvar" : "faltam campos")"
            )
        }

        private var prototypeDecorationData: TransactionFormPrototypeDecorationData {
            TransactionFormPrototypeDecorationData(
                title: store.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty ? "Nova transação" : store.description,
                kindLabel: prototypeKindLabel,
                kindColor: prototypeKindColor,
                amountText: store.amount.formatted(.currency(code: "BRL")),
                chips: [
                    prototypeAccountName,
                    prototypeCategoryName,
                    store.occurredAt.formatted(date: .abbreviated, time: .omitted),
                ],
                stateRows: [
                    .init(label: "Modo", value: store.isEditing ? "Edição" : "Nova"),
                    .init(label: "Tipo", value: prototypeKindLabel),
                    .init(label: "Conta", value: prototypeAccountName),
                    .init(label: "Categoria", value: prototypeCategoryName),
                    .init(label: "Valor", value: store.amount.formatted(.currency(code: "BRL"))),
                    .init(label: "Salvar", value: store.canSave ? "Pronto" : "Incompleto"),
                ]
            )
        }

        private func setPrototypeDate(dayOffset: Int) {
            guard let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) else { return }
            let current = store.occurredAt
            var components = Calendar.current.dateComponents([.hour, .minute], from: current)
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.year = dateComponents.year
            components.month = dateComponents.month
            components.day = dateComponents.day
            store.occurredAt = Calendar.current.date(from: components) ?? current
        }

        private func setPrototypeTime(hour: Int, minute: Int) {
            let current = store.occurredAt
            var components = Calendar.current.dateComponents([.year, .month, .day], from: current)
            components.hour = hour
            components.minute = minute
            store.occurredAt = Calendar.current.date(from: components) ?? current
        }

        private var prototypeAccountName: String {
            guard let accountId = store.accountId,
                  let account = store.state.account(for: accountId)
            else { return "Sem conta" }
            return store.state.displayName(for: account)
        }

        private var prototypeCategoryName: String {
            guard let categoryId = store.categoryId,
                  let category = store.state.category(for: categoryId)
            else { return "Sem categoria" }

            if let subcategoryId = store.subcategoryId, let subcategory = store.state.category(for: subcategoryId) {
                return "\(category.name) / \(subcategory.name)"
            }
            return category.name
        }

        private var prototypeKindLabel: String {
            switch store.selectedCategoryKind {
            case .income:
                "Receita"
            case .expense:
                "Despesa"
            case .transfer:
                "Transferência"
            case .none:
                "Sem tipo"
            }
        }

        private var prototypeKindColor: Color {
            switch store.selectedCategoryKind {
            case .income:
                .income
            case .expense:
                .expense
            case .transfer:
                .transfer
            case .none:
                GranaTheme.Palette.muted
            }
        }

        private func showPreviousPrototypeVariant() {
            prototypeVariant = prototypeVariant.previous
        }

        private func showNextPrototypeVariant() {
            prototypeVariant = prototypeVariant.next
        }
    #endif
}

private struct TransactionFormSection<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            Text(title)
                .font(GranaTheme.Typography.headline)
                .foregroundStyle(GranaTheme.Palette.ink)

            content()

            if let footer {
                Text(footer)
                    .font(GranaTheme.Typography.footnote)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TransactionFormFieldGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            content()
        }
        .padding(.vertical, GranaTheme.Spacing.xs)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
    }
}

private struct TransactionFormRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: GranaTheme.Spacing.md) {
            Text(title)
                .font(GranaTheme.Typography.calloutEmphasis)
                .foregroundStyle(GranaTheme.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.ink)
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .frame(minHeight: 44)
    }
}

private struct TransactionFormEmptyRow: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .font(GranaTheme.Typography.callout)
            .foregroundStyle(GranaTheme.Palette.muted)
            .padding(.horizontal, GranaTheme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

private struct TransactionFormDivider: View {
    var body: some View {
        Divider()
            .overlay(GranaTheme.Palette.line)
            .padding(.leading, GranaTheme.Spacing.md)
    }
}

private struct TransactionFormConfirmationOverlay: View {
    enum ConfirmStyle {
        case primary
        case destructive
    }

    let icon: String
    let tint: Color
    let title: String
    let message: String
    let cancelTitle: String
    let confirmTitle: String
    let confirmStyle: ConfirmStyle
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(GranaTheme.Palette.ink.opacity(0.20))
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: GranaTheme.IconSize.medium, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.top, GranaTheme.Spacing.xxs)

                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                        Text(title)
                            .font(GranaTheme.Typography.title3)
                            .foregroundStyle(GranaTheme.Palette.ink)

                        Text(message)
                            .font(GranaTheme.Typography.callout)
                            .foregroundStyle(GranaTheme.Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: GranaTheme.Spacing.sm) {
                    Spacer(minLength: GranaTheme.Spacing.none)

                    Button(cancelTitle, action: onCancel)
                        .buttonStyle(GranaSecondaryButtonStyle())

                    confirmButton
                }
            }
            .padding(GranaTheme.Spacing.lg)
            .frame(maxWidth: 420, alignment: .leading)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
            .padding(GranaTheme.Spacing.lg)
        }
    }

    @ViewBuilder
    private var confirmButton: some View {
        switch confirmStyle {
        case .primary:
            Button(confirmTitle, action: onConfirm)
                .buttonStyle(GranaPrimaryButtonStyle())
        case .destructive:
            Button(confirmTitle, action: onConfirm)
                .buttonStyle(GranaDestructiveButtonStyle())
        }
    }
}
