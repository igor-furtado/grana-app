import ComposableArchitecture
import SwiftUI

struct TransactionFormView: View {
    @Bindable var store: StoreOf<TransactionFormFeature>
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
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
    }

    private var header: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                Text(store.title)
                    .font(GranaTheme.Typography.title3)
                    .foregroundStyle(GranaTheme.Palette.tealDeep)

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

    private var activeFormContent: some View {
        defaultFormContent
    }

    private var defaultFormContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                formExposedField(title: "Descrição") { formDescriptionField }
                formExposedField(title: "Valor") { formAmountField }
                formExposedField(title: "Conta") { formAccountSelector }
                formExposedField(title: "Categoria") { formCategorySelector }

                if showsSubcategoryRow {
                    formExposedField(title: "Subcategoria") { formSubcategorySelector }
                }

                if showsDestinationAccountRow {
                    formExposedField(title: "Conta de destino") { formDestinationSelector }
                }

                if showsStatementPaymentSection {
                    formExposedField(title: "Pagamento de fatura") {
                        formStatementPaymentSummary
                    }
                }

                formExposedDateTimeRow
                formExposedField(title: "Notas") { formNotesField }
            }
            .padding(GranaTheme.Spacing.lg)
        }
        .scrollIndicators(.visible)
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

    private func formExposedField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            Text(title)
                .font(GranaTheme.Typography.subheadline)
                .foregroundStyle(GranaTheme.Palette.ink)
            content()
        }
    }

    private var formExposedDateTimeRow: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
            formExposedField(title: "Data") { formDateSelector }
            formExposedField(title: "Hora") { formTimeSelector }
        }
    }

    private var formDescriptionField: some View {
        AppUI.TextField(
            label: "Descrição",
            text: $store.description,
            placeholder: "Ex: almoço no restaurante",
            textAlignment: .trailing
        )
        .focused($focusedField, equals: .description)
    }

    private var formAmountField: some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            Text("R$")
                .font(GranaTheme.Typography.moneyHeadline)
                .foregroundStyle(GranaTheme.Palette.muted)

            AppUI.CurrencyField(label: "Valor", cents: $store.amountCents)
                .font(GranaTheme.Typography.moneyTitle3)

            Spacer(minLength: GranaTheme.Spacing.none)
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .padding(.vertical, GranaTheme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background(formControlBackground)
    }

    private var formAccountSelector: some View {
        AppUI.Selector(
            label: "Conta",
            options: accountOptions,
            selection: $store.accountId,
            icon: AppIcon.sidebarAccounts.systemImage
        )
    }

    private var formCategorySelector: some View {
        AppUI.Selector(
            label: "Categoria",
            options: categoryOptions,
            selection: $store.categoryId,
            icon: "tag"
        )
    }

    private var formSubcategorySelector: some View {
        AppUI.Selector(
            label: "Subcategoria",
            options: subcategoryOptions,
            selection: $store.subcategoryId,
            includesNoneOption: true,
            noneOptionTitle: "Sem subcategoria",
            icon: "square.grid.2x2"
        )
    }

    private var formDestinationSelector: some View {
        AppUI.Selector(
            label: "Conta de destino",
            options: destinationAccountOptions,
            selection: $store.destinationAccountId,
            includesNoneOption: true,
            noneOptionTitle: "Selecionar depois",
            icon: "arrow.left.arrow.right"
        )
    }

    private var formDateSelector: some View {
        TransactionFormPrototypeDateSelector(selection: $store.occurredAt)
    }

    private var formTimeSelector: some View {
        TransactionFormPrototypeTimeSelector(selection: $store.occurredAt)
    }

    private var formNotesField: some View {
        TransactionFormPrototypeNotesField(text: $store.notes, style: .panel)
    }

    private var formStatementPaymentSummary: some View {
        TransactionFormPrototypeStatementSummary(items: statementPreviewItems)
    }

    private var formControlBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(GranaTheme.Palette.paper.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GranaTheme.Palette.line, lineWidth: 1)
            }
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

    private var statementPreviewItems: [TransactionFormPrototypeStatementItem] {
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
