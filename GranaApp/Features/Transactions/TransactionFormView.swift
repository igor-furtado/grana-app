import ComposableArchitecture
import SwiftUI
#if DEBUG && canImport(AppKit)
    import AppKit
#endif

struct TransactionFormView: View {
    @Bindable var store: StoreOf<TransactionFormFeature>
    @FocusState private var focusedField: Field?
    #if DEBUG
        @State private var prototypeVariant: TransactionFormPrototypeVariant = .summary
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
            case .summary:
                prototypeSummaryContent
            case .ledger:
                prototypeLedgerContent
            case .workflow:
                prototypeWorkflowContent
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

    private var prototypeSummaryContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                prototypeAssumptionBanner
                prototypeHeroCard
                essentialSection
                classificationSection

                if showsRefundSection {
                    refundSection
                }

                if showsStatementPaymentSection {
                    statementPaymentSection
                }

                timingSection
                notesSection
            }
            .padding(GranaTheme.Spacing.lg)
        }
        .scrollIndicators(.visible)
    }

    private var prototypeLedgerContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                prototypeAssumptionBanner

                TransactionFormSection(
                    title: "Lançamento",
                    footer: prototypeVariant.name
                ) {
                    TransactionFormFieldGroup {
                        descriptionRow
                        TransactionFormDivider()
                        amountRow
                        TransactionFormDivider()
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

                        TransactionFormDivider()
                        dateRow
                        TransactionFormDivider()
                        timeRow
                    }
                }

                if showsRefundSection {
                    refundSection
                }

                if showsStatementPaymentSection {
                    statementPaymentSection
                }

                TransactionFormSection(title: "Notas e contexto") {
                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                        prototypeLiveSummaryCard
                        notesSection
                    }
                }
            }
            .padding(GranaTheme.Spacing.lg)
        }
        .scrollIndicators(.visible)
    }

    private var prototypeWorkflowContent: some View {
        ScrollView {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.lg) {
                LazyVStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                    prototypeAssumptionBanner

                    TransactionFormSection(title: "1. O que aconteceu?") {
                        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                            prototypeStepHighlight(
                                title: "Resumo rápido",
                                message: "Descrição e valor aparecem primeiro para ancorar a decisão."
                            )

                            TransactionFormFieldGroup {
                                descriptionRow
                                TransactionFormDivider()
                                amountRow
                            }
                        }
                    }

                    TransactionFormSection(title: "2. Como classificar?") {
                        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
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

                            if showsRefundSection {
                                refundSection
                            }

                            if showsStatementPaymentSection {
                                statementPaymentSection
                            }
                        }
                    }

                    TransactionFormSection(title: "3. Quando e por quê?") {
                        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                            TransactionFormFieldGroup {
                                dateRow
                                TransactionFormDivider()
                                timeRow
                            }

                            notesSection
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                    prototypeLiveSummaryCard
                    prototypeDecisionRail
                }
                .frame(width: 180, alignment: .topLeading)
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
            Text(
                "Protótipo descartável: três variantes da TransactionFormView dentro do drawer, no mesmo ponto de uso."
            )
            .font(GranaTheme.Typography.caption1)
            .foregroundStyle(GranaTheme.Palette.muted)
            .padding(.horizontal, GranaTheme.Spacing.md)
            .padding(.vertical, GranaTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.control)
        }

        private var prototypeHeroCard: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                        Text(store.description.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty ? "Nova transação" : store.description)
                            .font(GranaTheme.Typography.title3)
                            .foregroundStyle(GranaTheme.Palette.ink)
                            .lineLimit(2)

                        Text(prototypeKindLabel)
                            .font(GranaTheme.Typography.caption1Emphasis)
                            .foregroundStyle(prototypeKindColor)
                    }

                    Spacer(minLength: GranaTheme.Spacing.none)

                    Text(store.amount.formatted(.currency(code: "BRL")))
                        .font(GranaTheme.Typography.moneyTitle2)
                        .foregroundStyle(GranaTheme.Palette.ink)
                }

                HStack(spacing: GranaTheme.Spacing.xs) {
                    prototypePill(title: prototypeAccountName)
                    prototypePill(title: prototypeCategoryName)
                    prototypePill(title: store.occurredAt.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .padding(GranaTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
        }

        private var prototypeLiveSummaryCard: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                Text("Estado ao vivo")
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.ink)

                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                    prototypeSnapshotRow(label: "Modo", value: store.isEditing ? "Edição" : "Nova")
                    prototypeSnapshotRow(label: "Tipo", value: prototypeKindLabel)
                    prototypeSnapshotRow(label: "Conta", value: prototypeAccountName)
                    prototypeSnapshotRow(label: "Categoria", value: prototypeCategoryName)
                    prototypeSnapshotRow(label: "Valor", value: store.amount.formatted(.currency(code: "BRL")))
                    prototypeSnapshotRow(
                        label: "Salvar",
                        value: store.canSave ? "Pronto" : "Incompleto"
                    )
                }
            }
            .padding(GranaTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
        }

        private var prototypeDecisionRail: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                Text("Leitura")
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.ink)

                prototypeStepHighlight(
                    title: "Primeiro",
                    message: "Valor e descrição antes da mecânica de classificação."
                )
                prototypeStepHighlight(
                    title: "Depois",
                    message: "Conta, categoria e regras de cartão em um único bloco."
                )
                prototypeStepHighlight(
                    title: "Por fim",
                    message: "Data, hora e notas como confirmação."
                )
            }
            .padding(GranaTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
        }

        private var prototypeSnapshot: TransactionFormPrototypeSnapshot {
            TransactionFormPrototypeSnapshot(
                title: prototypeVariant.displayTitle,
                summary: "\(store.isEditing ? "Edição" : "Nova") · \(prototypeKindLabel) · \(store.amount.formatted(.currency(code: "BRL")))",
                details: "\(prototypeAccountName) · \(prototypeCategoryName) · \(store.canSave ? "pronto para salvar" : "faltam campos")"
            )
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

            if let subcategoryId = store.subcategoryId,
               let subcategory = store.state.category(for: subcategoryId)
            {
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

        private func prototypePill(title: String) -> some View {
            Text(title)
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(GranaTheme.Palette.ink)
                .lineLimit(1)
                .padding(.horizontal, GranaTheme.Spacing.sm)
                .padding(.vertical, GranaTheme.Spacing.xs)
                .background(
                    Capsule()
                        .fill(GranaTheme.Palette.paper)
                )
        }

        private func prototypeStepHighlight(title: String, message: String) -> some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                Text(title)
                    .font(GranaTheme.Typography.caption1Emphasis)
                    .foregroundStyle(GranaTheme.Palette.tealDeep)
                Text(message)
                    .font(GranaTheme.Typography.footnote)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(GranaTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                    .fill(GranaTheme.Palette.paper)
            )
        }

        private func prototypeSnapshotRow(label: String, value: String) -> some View {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                Text(label)
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .frame(width: 58, alignment: .leading)
                Text(value)
                    .font(GranaTheme.Typography.subheadlineEmphasis)
                    .foregroundStyle(GranaTheme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

#if DEBUG
    private enum TransactionFormPrototypeVariant: String, CaseIterable, Identifiable {
        case summary = "A"
        case ledger = "B"
        case workflow = "C"

        var id: String {
            rawValue
        }

        var name: String {
            switch self {
            case .summary:
                "Resumo guiado"
            case .ledger:
                "Ficha contínua"
            case .workflow:
                "Fluxo com rail"
            }
        }

        var displayTitle: String {
            "\(rawValue) — \(name)"
        }

        var next: TransactionFormPrototypeVariant {
            let variants = Self.allCases
            guard let index = variants.firstIndex(of: self) else { return self }
            return variants[(index + 1) % variants.count]
        }

        var previous: TransactionFormPrototypeVariant {
            let variants = Self.allCases
            guard let index = variants.firstIndex(of: self) else { return self }
            return variants[(index - 1 + variants.count) % variants.count]
        }
    }

    private struct TransactionFormPrototypeSnapshot {
        let title: String
        let summary: String
        let details: String
    }

    private struct TransactionFormPrototypeSwitcher: View {
        @Binding var variant: TransactionFormPrototypeVariant
        let snapshot: TransactionFormPrototypeSnapshot
        let onPrevious: () -> Void
        let onNext: () -> Void

        var body: some View {
            HStack(spacing: GranaTheme.Spacing.sm) {
                prototypeButton(
                    systemImage: "arrow.left",
                    title: "Variante anterior",
                    action: onPrevious
                )

                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text(snapshot.title)
                        .font(GranaTheme.Typography.subheadlineEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)

                    Text(snapshot.summary)
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .lineLimit(1)

                    Text(snapshot.details)
                        .font(GranaTheme.Typography.caption2)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                prototypeButton(
                    systemImage: "arrow.right",
                    title: "Próxima variante",
                    action: onNext
                )
            }
            .padding(.horizontal, GranaTheme.Spacing.md)
            .padding(.vertical, GranaTheme.Spacing.sm)
            .frame(maxWidth: 460, alignment: .leading)
            .background(
                Capsule(style: .continuous)
                    .fill(GranaTheme.Palette.paperSolid.opacity(0.98))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(GranaTheme.Palette.line, lineWidth: 1)
            )
            .shadow(color: GranaTheme.Shadow.cardColor, radius: 18, x: 0, y: 8)
            .background(
                TransactionFormPrototypeKeyboardMonitor(
                    onPrevious: onPrevious,
                    onNext: onNext
                )
                .frame(width: 0, height: 0)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Seletor de variantes do protótipo")
            .accessibilityValue(variant.displayTitle)
        }

        private func prototypeButton(
            systemImage: String,
            title: String,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(GranaTheme.Palette.background)
                    )
            }
            .buttonStyle(.plain)
            .help(title)
            .accessibilityLabel(title)
        }
    }

    #if canImport(AppKit)
        private struct TransactionFormPrototypeKeyboardMonitor: NSViewRepresentable {
            let onPrevious: () -> Void
            let onNext: () -> Void

            func makeCoordinator() -> Coordinator {
                Coordinator(onPrevious: onPrevious, onNext: onNext)
            }

            func makeNSView(context: Context) -> NSView {
                let view = NSView(frame: .zero)
                context.coordinator.installMonitor()
                return view
            }

            func updateNSView(_ nsView: NSView, context: Context) {
                context.coordinator.onPrevious = onPrevious
                context.coordinator.onNext = onNext
            }

            static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
                coordinator.removeMonitor()
            }

            final class Coordinator {
                var onPrevious: () -> Void
                var onNext: () -> Void
                private var monitor: Any?

                init(
                    onPrevious: @escaping () -> Void,
                    onNext: @escaping () -> Void
                ) {
                    self.onPrevious = onPrevious
                    self.onNext = onNext
                }

                func installMonitor() {
                    guard monitor == nil else { return }

                    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                        guard let self else { return event }
                        guard self.shouldHandle(event: event) else { return event }

                        switch event.keyCode {
                        case 123:
                            onPrevious()
                            return nil
                        case 124:
                            onNext()
                            return nil
                        default:
                            return event
                        }
                    }
                }

                func removeMonitor() {
                    guard let monitor else { return }
                    NSEvent.removeMonitor(monitor)
                    self.monitor = nil
                }

                private func shouldHandle(event: NSEvent) -> Bool {
                    guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
                        return false
                    }
                    guard let responder = NSApp.keyWindow?.firstResponder else { return true }

                    if let textView = responder as? NSTextView,
                       textView.isEditable || textView.isFieldEditor
                    {
                        return false
                    }

                    if responder is NSTextField {
                        return false
                    }

                    return true
                }
            }
        }
    #endif
#endif
