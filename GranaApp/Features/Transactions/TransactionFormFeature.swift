import ComposableArchitecture
import Foundation

@Reducer
struct TransactionFormFeature {
    @ObservableState
    struct State: Equatable {
        var existing: Transaction?
        var transactions: [Transaction]
        var accounts: [Account]
        var institutions: [Institution]
        var bankDetails: [BankAccountDetails]
        var creditCards: [CreditCardDetails]
        var categories: [Category]
        var statements: [Statement]
        var statementPayments: [StatementPayment]
        var supportsAdvancedCardRules = true
        var calendar: Calendar
        var referenceDate: Date

        var description = ""
        var amountCents = 0
        var occurredAt: Date
        var accountId: UUID?
        var categoryId: UUID?
        var subcategoryId: UUID?
        var destinationAccountId: UUID?
        var installmentPlan: InstallmentPlan?
        var notes = ""
        var saveError: String?
        var isSaving = false
        var showsRetroactivePreview = false
        var showsDiscardConfirmation = false
        var initialValues = EditableValues()

        init(
            existing: Transaction? = nil,
            transactions: [Transaction],
            accounts: [Account],
            institutions: [Institution],
            bankDetails: [BankAccountDetails],
            creditCards: [CreditCardDetails],
            categories: [Category],
            statements: [Statement],
            statementPayments: [StatementPayment],
            occurredAt: Date = Date(),
            calendar: Calendar = .current,
            referenceDate: Date = Date()
        ) {
            self.existing = existing
            self.transactions = transactions
            self.accounts = accounts
            self.institutions = institutions
            self.bankDetails = bankDetails
            self.creditCards = creditCards
            self.categories = categories
            self.statements = statements
            self.statementPayments = statementPayments
            self.occurredAt = occurredAt
            self.calendar = calendar
            self.referenceDate = referenceDate

            if let existing {
                self.description = existing.description
                self.amountCents = Int(truncatingIfNeeded: Converters.decimalToCents(existing.amount))
                self.occurredAt = existing.occurredAt
                self.accountId = existing.accountId
                self.categoryId = existing.categoryId
                self.subcategoryId = existing.subcategoryId
                self.destinationAccountId = existing.destinationAccountId
                if existing.purchaseType == .installment {
                    let installmentIndex = existing.installmentIndex ?? 1
                    self.installmentPlan = .normalized(
                        index: installmentIndex,
                        count: existing.installmentCount ?? max(2, installmentIndex)
                    )
                }
                self.notes = existing.notes ?? ""
            } else {
                self.accountId = accounts.first?.id
                self.categoryId = rootCategories.first?.id
            }
            self.initialValues = EditableValues(state: self)
        }

        var isEditing: Bool {
            existing != nil
        }

        var title: String {
            isEditing ? "Editar transação" : "Nova transação"
        }

        var subtitle: String? {
            guard isEditing else { return nil }
            return "\(description) · \(amount.formatted(.currency(code: "BRL")))"
        }

        var saveButtonTitle: String {
            isEditing ? "Salvar" : "Adicionar"
        }

        var successNoticeTitle: String {
            isEditing ? "Transação salva" : "Transação adicionada"
        }

        var hasUnsavedChanges: Bool {
            EditableValues(state: self) != initialValues
        }

        var rootCategories: [Category] {
            categories.filter { $0.parentId == nil }
        }

        var canSave: Bool {
            guard !description.trimmingCharacters(in: .whitespaces).isEmpty,
                  amountCents > 0,
                  accountId != nil,
                  categoryId != nil
            else { return false }

            let invalidTransfer = selectedCategoryKind == .transfer && destinationAccountId == accountId
            if invalidTransfer {
                return false
            }

            return true
        }

        var amount: Decimal {
            Decimal(amountCents) / 100
        }

        var selectedCategoryKind: CategoryKind? {
            guard let categoryId else { return nil }
            return categories.first { $0.id == categoryId }?.kind
        }

        var sourceAccountOptions: [Account] {
            accounts.filter { account in
                let blockedCard = !supportsAdvancedCardRules
                    && account.type == .creditCard
                    && existing?.accountId != account.id
                if blockedCard {
                    return false
                }
                if account.archived {
                    return existing?.accountId == account.id
                }
                return true
            }
        }

        var destinationAccountOptions: [Account] {
            accounts.filter { account in
                guard account.id != accountId else { return false }
                let blockedCard = !supportsAdvancedCardRules
                    && account.type == .creditCard
                    && existing?.destinationAccountId != account.id
                if blockedCard {
                    return false
                }
                if account.archived {
                    return existing?.destinationAccountId == account.id
                }
                return true
            }
        }

        var isPayingCreditCard: Bool {
            guard selectedCategoryKind == .transfer,
                  let destinationAccountId,
                  let account = account(for: destinationAccountId)
            else { return false }
            return account.type == .creditCard
        }

        var selectedAccountIsCreditCard: Bool {
            guard let accountId, let account = account(for: accountId) else { return false }
            return account.type == .creditCard
        }

        var selectedCardDetails: CreditCardDetails? {
            guard let accountId else { return nil }
            return creditCards.first { $0.accountId == accountId }
        }

        var showsInstallmentFields: Bool {
            supportsAdvancedCardRules && selectedAccountIsCreditCard && selectedCategoryKind == .expense
        }

        var isInstallment: Bool {
            installmentPlan != nil
        }

        var installmentIndex: Int {
            installmentPlan?.index ?? InstallmentPlan.default.index
        }

        var installmentCount: Int {
            installmentPlan?.count ?? InstallmentPlan.default.count
        }

        var automaticPaymentPreview: [(statement: Statement, amount: Decimal)] {
            guard let destinationAccountId else { return [] }
            return automaticPaymentPreview(
                accountId: destinationAccountId,
                amount: amount,
                occurredAt: occurredAt
            )
        }

        var requiresRetroactivePreview: Bool {
            let isPast = occurredAt < calendar.startOfDay(for: referenceDate)
            guard isPast else { return false }
            return selectedAccountIsCreditCard || isPayingCreditCard
        }

        var retroactivePreviewText: String {
            var effects: [String] = []
            if selectedAccountIsCreditCard {
                effects
                    .append(
                        "A compra será vinculada à fatura que cobre a data da transação; fechamento da fatura permanece editável na tela de cartões."
                    )
            }
            if isPayingCreditCard {
                effects
                    .append(
                        "Este pagamento será vinculado às dívidas elegíveis mais antigas. "
                            + "Pagamentos já registrados em outras faturas não serão redistribuídos."
                    )
            }
            return effects.joined(separator: "\n")
        }

        func category(for id: UUID) -> Category? {
            categories.first { $0.id == id }
        }

        func account(for id: UUID) -> Account? {
            accounts.first { $0.id == id }
        }

        func displayName(for account: Account) -> String {
            Account.displayName(
                for: account,
                institutions: institutions,
                bankAccounts: bankDetails,
                creditCards: creditCards
            )
        }

        func subcategories(of parentId: UUID) -> [Category] {
            categories.filter { $0.parentId == parentId }
        }

        func remainingAmount(of statement: Statement) -> Decimal {
            statement.remainingAmount
        }

        func automaticPaymentPreview(
            accountId: UUID,
            amount: Decimal,
            occurredAt: Date
        ) -> [(statement: Statement, amount: Decimal)] {
            var remaining = amount
            var result: [(statement: Statement, amount: Decimal)] = []
            for statement in openStatements(for: accountId) where remaining > 0 {
                let hasEntryByPaymentDate = transactions.contains {
                    $0.statementId == statement.id && $0.occurredAt <= occurredAt
                }
                guard hasEntryByPaymentDate else { continue }
                let applied = min(statement.remainingAmount, remaining)
                guard applied > 0 else { continue }
                result.append((statement: statement, amount: applied))
                remaining -= applied
            }
            if remaining > 0, let lastIndex = result.indices.last {
                result[lastIndex].amount += remaining
            }
            return result
        }

        func mutationInput() -> TransactionMutationInput? {
            guard let accountId, let categoryId else { return nil }
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let purchaseType: TransactionPurchaseType?
            let mutationInstallmentIndex: Int?
            let mutationInstallmentCount: Int?
            if showsInstallmentFields {
                purchaseType = installmentPlan == nil ? .cash : .installment
                mutationInstallmentIndex = installmentPlan?.index
                mutationInstallmentCount = installmentPlan?.count
            } else {
                purchaseType = nil
                mutationInstallmentIndex = nil
                mutationInstallmentCount = nil
            }
            return TransactionMutationInput(
                accountId: accountId,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                amount: amount,
                occurredAt: occurredAt,
                originOccurredAt: originOccurredAtForMutation,
                purchaseType: purchaseType,
                installmentIndex: mutationInstallmentIndex,
                installmentCount: mutationInstallmentCount,
                description: description,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                destinationAccountId: selectedCategoryKind == .transfer ? destinationAccountId : nil
            )
        }

        var originOccurredAtForMutation: Date? {
            guard showsInstallmentFields, let installmentPlan else {
                return nil
            }
            return installmentPlan.originOccurredAt(for: occurredAt, calendar: calendar)
        }

        mutating func accountSelectionChanged() {
            if destinationAccountId == accountId {
                destinationAccountId = nil
            }
            normalizeInstallmentSelection()
        }

        mutating func categorySelectionChanged() {
            subcategoryId = nil
            if selectedCategoryKind != .transfer {
                destinationAccountId = nil
            }
            normalizeInstallmentSelection()
        }

        mutating func normalizeInstallmentSelection() {
            if !showsInstallmentFields {
                installmentPlan = nil
            }
        }

        mutating func setInstallmentEnabled(_ isEnabled: Bool) {
            installmentPlan = isEnabled ? installmentPlan ?? .default : nil
            normalizeInstallmentSelection()
        }

        mutating func setInstallmentIndex(_ index: Int) {
            installmentPlan = (installmentPlan ?? .default).updatingIndex(index)
            normalizeInstallmentSelection()
        }

        mutating func setInstallmentCount(_ count: Int) {
            installmentPlan = (installmentPlan ?? .default).updatingCount(count)
            normalizeInstallmentSelection()
        }

        private func openStatements(for accountId: UUID) -> [Statement] {
            statements
                .filter { $0.accountId == accountId && $0.remainingAmount > 0 }
                .sorted { $0.closingDate < $1.closingDate }
        }

        struct EditableValues: Equatable {
            var description = ""
            var amountCents = 0
            var occurredAt = Date(timeIntervalSince1970: 0)
            var accountId: UUID?
            var categoryId: UUID?
            var subcategoryId: UUID?
            var destinationAccountId: UUID?
            var installmentPlan: InstallmentPlan?
            var notes = ""

            init() {}

            init(state: State) {
                self.description = state.description
                self.amountCents = state.amountCents
                self.occurredAt = state.occurredAt
                self.accountId = state.accountId
                self.categoryId = state.categoryId
                self.subcategoryId = state.subcategoryId
                self.destinationAccountId = state.destinationAccountId
                self.installmentPlan = state.installmentPlan
                self.notes = state.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case cancelButtonTapped
        case discardChangesConfirmed
        case discardChangesDismissed
        case installmentCountChanged(Int)
        case installmentIndexChanged(Int)
        case installmentToggled(Bool)
        case saveButtonTapped
        case retroactivePreviewCancelTapped
        case retroactivePreviewConfirmTapped
        case saveSucceeded
        case saveFailed(String)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case cancel
            case discarded
            case saved
        }
    }

    @Dependency(\.transactionsClient) private var transactionsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.accountId):
                state.accountSelectionChanged()
                return .none

            case .binding(\.categoryId):
                state.categorySelectionChanged()
                return .none

            case let .installmentCountChanged(count):
                state.setInstallmentCount(count)
                return .none

            case let .installmentIndexChanged(index):
                state.setInstallmentIndex(index)
                return .none

            case let .installmentToggled(isEnabled):
                state.setInstallmentEnabled(isEnabled)
                return .none

            case .binding:
                return .none

            case .cancelButtonTapped:
                guard !state.isSaving else { return .none }
                if state.hasUnsavedChanges {
                    state.showsDiscardConfirmation = true
                    return .none
                }
                return .send(.delegate(.cancel))

            case .discardChangesConfirmed:
                guard !state.isSaving else { return .none }
                state.showsDiscardConfirmation = false
                return .send(.delegate(.discarded))

            case .discardChangesDismissed:
                state.showsDiscardConfirmation = false
                return .none

            case .saveButtonTapped:
                guard state.canSave else { return .none }
                if state.requiresRetroactivePreview {
                    state.showsRetroactivePreview = true
                    return .none
                }
                return save(&state)

            case .retroactivePreviewCancelTapped:
                state.showsRetroactivePreview = false
                return .none

            case .retroactivePreviewConfirmTapped:
                state.showsRetroactivePreview = false
                guard state.canSave else { return .none }
                return save(&state)

            case .saveSucceeded:
                state.isSaving = false
                return .send(.delegate(.saved))

            case let .saveFailed(message):
                state.isSaving = false
                state.saveError = message
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func save(_ state: inout State) -> Effect<Action> {
        guard let input = state.mutationInput() else { return .none }
        let existingId = state.existing?.id
        let successTitle = state.successNoticeTitle
        state.isSaving = true
        state.saveError = nil

        return .run { send in
            do {
                if let existingId {
                    try await transactionsClient.update(existingId, input)
                } else {
                    try await transactionsClient.create(input)
                }
                await noticeClient.success(successTitle, nil)
                await send(.saveSucceeded)
            } catch {
                await noticeClient.report(error, "Falha ao salvar transação")
                await send(.saveFailed(error.localizedDescription))
            }
        }
    }
}
