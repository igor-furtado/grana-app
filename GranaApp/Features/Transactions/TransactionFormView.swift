import AppUI
import ComposableArchitecture
import SwiftUI

struct TransactionFormView: View {
    @Bindable var store: StoreOf<TransactionFormFeature>
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            GranaBackground()

            AppUI.Form.Shell {
                header

                Form {
                    detailsSection
                    classificationSection

                    if showsInstallmentSection {
                        installmentSection
                    }

                    if showsStatementPaymentSection {
                        statementPaymentSection
                    }

                    scheduleSection
                    notesSection

                    if let saveError = store.saveError {
                        errorSection(message: saveError)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

                actions
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 560, idealWidth: 560, maxWidth: 560, minHeight: 640)
        .sheet(
            isPresented: Binding(
                get: { store.showsDiscardConfirmation },
                set: { isPresented in
                    if !isPresented {
                        store.send(.discardChangesDismissed)
                    }
                }
            )
        ) {
            TransactionFormConfirmationSheet(
                title: "Descartar alterações?",
                message: "As mudanças desta transação serão perdidas.",
                cancelTitle: "Continuar editando",
                confirmTitle: "Descartar",
                confirmStyle: .destructive,
                onCancel: { store.send(.discardChangesDismissed) },
                onConfirm: { store.send(.discardChangesConfirmed) }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { store.showsRetroactivePreview },
                set: { isPresented in
                    if !isPresented {
                        store.send(.retroactivePreviewCancelTapped)
                    }
                }
            )
        ) {
            TransactionFormConfirmationSheet(
                title: "Prévia do recálculo",
                message: store.state.retroactivePreviewText,
                cancelTitle: "Cancelar",
                confirmTitle: "Confirmar alteração",
                confirmStyle: .primary,
                onCancel: { store.send(.retroactivePreviewCancelTapped) },
                onConfirm: { store.send(.retroactivePreviewConfirmTapped) }
            )
        }
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
        AppUI.Form.Header(
            title: store.title,
            subtitle: store.subtitle ?? "Transação manual com conta, categoria, data e valor."
        )
    }

    private var detailsSection: some View {
        Section {
            AppUI.TextField(
                label: "Descrição",
                text: $store.description,
                placeholder: "Ex: almoço no restaurante",
                textAlignment: .trailing
            )
            .focused($focusedField, equals: .description)

            AppUI.CurrencyField(
                label: "Valor",
                cents: $store.amountCents
            )
        } header: {
            AppUI.Form.SectionHeader(title: "Detalhes")
        }
    }

    private var classificationSection: some View {
        Section {
            AppUI.Selector(
                label: "Conta",
                options: accountOptions,
                selection: $store.accountId,
                icon: AppUI.Icon.sidebarAccounts.systemImage
            )
            AppUI.Selector(
                label: "Categoria",
                options: categoryOptions,
                selection: $store.categoryId,
                icon: "tag"
            )

            if showsSubcategoryRow {
                AppUI.Selector(
                    label: "Subcategoria",
                    options: subcategoryOptions,
                    selection: $store.subcategoryId,
                    includesNoneOption: true,
                    noneOptionTitle: "Sem subcategoria",
                    icon: "square.grid.2x2"
                )
            }

            if showsDestinationAccountRow {
                AppUI.Selector(
                    label: "Conta de destino",
                    options: destinationAccountOptions,
                    selection: $store.destinationAccountId,
                    includesNoneOption: true,
                    noneOptionTitle: "Selecionar depois",
                    icon: "arrow.left.arrow.right"
                )
            }
        } header: {
            AppUI.Form.SectionHeader(title: "Classificação")
        } footer: {
            if store.selectedCategoryKind == .transfer {
                AppUI.Form.SectionFooter(
                    text: "Transferências exigem uma conta de destino diferente da conta de origem."
                )
            }
        }
    }

    private var statementPaymentSection: some View {
        Section {
            TransactionStatementSummary(items: statementPreviewItems)
        } header: {
            AppUI.Form.SectionHeader(title: "Pagamento de fatura")
        } footer: {
            AppUI.Form.SectionFooter(text: "Prévia das faturas elegíveis nesta data para o valor informado.")
        }
    }

    private var installmentSection: some View {
        Section {
            AppUI.Toggle(
                label: "Compra parcelada",
                isOn: Binding(
                    get: { store.isInstallment },
                    set: { store.send(.installmentToggled($0)) }
                )
            )

            if store.isInstallment {
                InstallmentStepperField(
                    label: "Parcela atual",
                    value: Binding(
                        get: { store.installmentIndex },
                        set: { store.send(.installmentIndexChanged($0)) }
                    ),
                    range: 1 ... max(1, store.installmentCount)
                )
                InstallmentStepperField(
                    label: "Total de parcelas",
                    value: Binding(
                        get: { store.installmentCount },
                        set: { store.send(.installmentCountChanged($0)) }
                    ),
                    range: 2 ... 60
                )
            }
        } header: {
            AppUI.Form.SectionHeader(title: "Parcelamento")
        } footer: {
            if store.isInstallment {
                AppUI.Form.SectionFooter(text: "A data representa a competência da parcela atual.")
            }
        }
    }

    private var scheduleSection: some View {
        Section {
            AppUI.DatePicker(
                label: "Data",
                selection: $store.occurredAt,
                displayedComponents: .date
            )
            AppUI.DatePicker(
                label: "Hora",
                selection: $store.occurredAt,
                displayedComponents: .hourAndMinute
            )
        } header: {
            AppUI.Form.SectionHeader(title: "Data e hora")
        }
    }

    private var notesSection: some View {
        Section {
            TransactionNotesField(text: $store.notes)
        } header: {
            AppUI.Form.SectionHeader(title: "Notas")
        }
    }

    private func errorSection(message: String) -> some View {
        Section {
            AppUI.Form.ErrorMessage(message: message)
        } header: {
            AppUI.Form.SectionHeader(title: "Erro ao salvar")
        }
    }

    private var actions: some View {
        AppUI.Form.Actions {
            Button("Cancelar") {
                store.send(.cancelButtonTapped)
            }
            .buttonStyle(GranaSecondaryButtonStyle())
            .disabled(store.isSaving)

            Button {
                store.send(.saveButtonTapped)
            } label: {
                HStack(spacing: AppUI.Theme.Spacing.xs) {
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

    private var showsInstallmentSection: Bool {
        store.showsInstallmentFields
    }

    private var showsStatementPaymentSection: Bool {
        store.supportsAdvancedCardRules && store.isPayingCreditCard
    }

    private var accountOptions: [AppUI.SelectorOption<UUID>] {
        store.state.sourceAccountOptions.map { account in
            .init(
                id: account.id,
                title: store.state.displayName(for: account),
                badge: account.type == .creditCard ? "Cartão" : "Conta"
            )
        }
    }

    private var categoryOptions: [AppUI.SelectorOption<UUID>] {
        store.state.rootCategories.map { category in
            .init(
                id: category.id,
                title: category.name,
                badge: category.kind.displayName
            )
        }
    }

    private var subcategoryOptions: [AppUI.SelectorOption<UUID>] {
        selectedSubcategories.map { category in
            .init(id: category.id, title: category.name)
        }
    }

    private var destinationAccountOptions: [AppUI.SelectorOption<UUID>] {
        store.state.destinationAccountOptions.map { account in
            .init(
                id: account.id,
                title: store.state.displayName(for: account),
                badge: account.type == .creditCard ? "Cartão" : "Conta"
            )
        }
    }

    private var statementPreviewItems: [StatementPreviewItem] {
        if store.state.automaticPaymentPreview.isEmpty {
            return [.empty(message: "Nenhuma dívida elegível nessa data.")]
        }

        return store.state.automaticPaymentPreview.map { item in
            .filled(
                title: statementPreviewTitle(for: item.statement),
                value: item.amount.formatted(.currency(code: "BRL"))
            )
        }
    }

    private func statementPreviewTitle(for statement: Statement) -> String {
        let monthYear = GranaDateFormat.dateOnlyMonthYear(statement.dueDate)
        let remaining = store.state.remainingAmount(of: statement)
        let total = statement.totalAmount
        let remainingStr = remaining.formatted(.currency(code: "BRL"))
        let totalStr = total.formatted(.currency(code: "BRL"))
        return "Fatura \(monthYear) · faltam \(remainingStr) de \(totalStr)"
    }

    private enum Field: Hashable {
        case description
    }
}

private struct InstallmentStepperField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        AppUI.Field(label: label, leadingSystemImage: "number") {
            HStack(spacing: AppUI.Theme.Spacing.sm) {
                Text("\(value)")
                    .font(AppUI.Theme.Typography.bodyEmphasis)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
                    .monospacedDigit()

                Stepper("", value: $value, in: range)
                    .labelsHidden()
            }
            .frame(maxWidth: 128)
        }
    }
}

private enum StatementPreviewItem: Identifiable {
    case empty(message: String)
    case filled(title: String, value: String)

    var id: String {
        switch self {
        case let .empty(message):
            "empty-\(message)"
        case let .filled(title, value):
            "filled-\(title)-\(value)"
        }
    }
}

private struct TransactionStatementSummary: View {
    let items: [StatementPreviewItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            ForEach(items) { item in
                switch item {
                case let .empty(message):
                    Text(message)
                        .font(AppUI.Theme.Typography.callout)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppUI.Theme.Spacing.sm)
                        .background(rowBackground)
                case let .filled(title, value):
                    HStack(alignment: .top, spacing: AppUI.Theme.Spacing.sm) {
                        Text(title)
                            .font(AppUI.Theme.Typography.footnote)
                            .foregroundStyle(AppUI.Theme.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: AppUI.Theme.Spacing.none)
                        Text(value)
                            .font(AppUI.Theme.Typography.moneyFootnote)
                            .foregroundStyle(AppUI.Theme.Palette.ink)
                    }
                    .padding(AppUI.Theme.Spacing.sm)
                    .background(rowBackground)
                }
            }
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: AppUI.Theme.Radius.control, style: .continuous)
            .fill(AppUI.Theme.Palette.paper)
    }
}

private struct TransactionNotesField: View {
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Observação, contexto, lembrete…")
                    .font(AppUI.Theme.Typography.callout)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
                    .padding(.horizontal, AppUI.Theme.Spacing.md)
                    .padding(.vertical, AppUI.Theme.Spacing.sm)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(AppUI.Theme.Typography.body)
                .foregroundStyle(AppUI.Theme.Palette.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .padding(AppUI.Theme.Spacing.xs)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppUI.Theme.Palette.paper.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppUI.Theme.Palette.line, lineWidth: 1)
                }
        )
    }
}

private struct TransactionFormConfirmationSheet: View {
    enum ConfirmStyle {
        case primary
        case destructive
    }

    let title: String
    let message: String
    let cancelTitle: String
    let confirmTitle: String
    let confirmStyle: ConfirmStyle
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            GranaBackground()

            AppUI.Form.Shell {
                AppUI.Form.Header(
                    title: title,
                    subtitle: message
                )

                AppUI.Form.Actions {
                    Button(cancelTitle, action: onCancel)
                        .buttonStyle(GranaSecondaryButtonStyle())

                    confirmButton
                }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(width: AppUI.Modal.SheetSize.compactWidth)
        .presentationSizing(.fitted)
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
