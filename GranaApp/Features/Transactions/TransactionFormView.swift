import ComposableArchitecture
import SwiftUI

struct TransactionFormView: View {
    @Bindable var store: StoreOf<TransactionFormFeature>
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            VStack(spacing: GranaTheme.Spacing.none) {
                header
                Divider()
                    .overlay(GranaTheme.Palette.line)
                formContent
                Divider()
                    .overlay(GranaTheme.Palette.line)
                actions
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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

    private var formContent: some View {
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

    private var essentialSection: some View {
        TransactionFormSection(title: "Essencial") {
            TransactionFormFieldGroup {
                TransactionFormRow(title: "Descrição") {
                    TextField("Descrição", text: $store.description, prompt: Text("Ex: Almoço no restaurante"))
                        .textFieldStyle(.plain)
                        .font(GranaTheme.Typography.bodyEmphasis)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .description)
                }

                TransactionFormDivider()

                TransactionFormRow(title: "Valor") {
                    CurrencyField(cents: $store.amountCents)
                        .font(GranaTheme.Typography.moneyTitle3)
                        .frame(maxWidth: 180, alignment: .trailing)
                }
            }
        }
    }

    private var classificationSection: some View {
        TransactionFormSection(title: "Classificação") {
            TransactionFormFieldGroup {
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

                TransactionFormDivider()

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

                if let categoryId = store.categoryId {
                    let subcategories = store.state.subcategories(of: categoryId)
                    if !subcategories.isEmpty {
                        TransactionFormDivider()

                        TransactionFormRow(title: "Subcategoria") {
                            Picker("", selection: $store.subcategoryId) {
                                Text("(nenhuma)").tag(UUID?.none)
                                ForEach(subcategories) { subcategory in
                                    Text(subcategory.name).tag(UUID?.some(subcategory.id))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: 250, alignment: .trailing)
                        }
                    }
                }

                if store.selectedCategoryKind == .transfer {
                    TransactionFormDivider()

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
                TransactionFormRow(title: "Data") {
                    DatePicker("", selection: $store.occurredAt, displayedComponents: [.date])
                        .labelsHidden()
                        .frame(maxWidth: 180, alignment: .trailing)
                }

                TransactionFormDivider()

                TransactionFormRow(title: "Hora") {
                    DatePicker("", selection: $store.occurredAt, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .frame(maxWidth: 180, alignment: .trailing)
                }
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
