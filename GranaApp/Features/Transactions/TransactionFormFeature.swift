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

        var description = ""
        var amountCents = 0
        var occurredAt: Date
        var accountId: UUID?
        var categoryId: UUID?
        var subcategoryId: UUID?
        var destinationAccountId: UUID?
        var refundOfTransactionId: UUID?
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
            occurredAt: Date = Date()
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

            if let existing {
                self.description = existing.description
                self.amountCents = Int(truncatingIfNeeded: Converters.decimalToCents(existing.amount))
                self.occurredAt = existing.occurredAt
                self.accountId = existing.accountId
                self.categoryId = existing.categoryId
                self.subcategoryId = existing.subcategoryId
                self.destinationAccountId = existing.destinationAccountId
                self.refundOfTransactionId = existing.refundOfTransactionId
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

            if let refundOfTransactionId {
                let purchase = refundablePurchases.first { $0.id == refundOfTransactionId }
                if let purchase, amount > remainingRefundableAmount(for: purchase) {
                    return false
                }
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

        var refundablePurchases: [Transaction] {
            refundablePurchases(
                accountId: accountId,
                occurredAt: occurredAt,
                excluding: existing?.id
            )
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
            let isPast = occurredAt < Calendar.current.startOfDay(for: Date())
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
            if let existing {
                let linkedRefunds = transactions.filter {
                    $0.refundOfTransactionId == existing.id
                }.count
                if linkedRefunds > 0 {
                    effects.append("\(linkedRefunds) estorno(s) vinculado(s) serão revalidados.")
                }
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

        func remainingRefundableAmount(for purchase: Transaction) -> Decimal {
            let refunded = transactions
                .filter { $0.refundOfTransactionId == purchase.id }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return max(0, purchase.amount - refunded)
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
            return TransactionMutationInput(
                accountId: accountId,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                amount: amount,
                occurredAt: occurredAt,
                description: description,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                destinationAccountId: selectedCategoryKind == .transfer ? destinationAccountId : nil,
                refundOfTransactionId: refundOfTransactionId
            )
        }

        mutating func accountSelectionChanged() {
            if destinationAccountId == accountId {
                destinationAccountId = nil
            }
            if !refundablePurchases.contains(where: { $0.id == refundOfTransactionId }) {
                refundOfTransactionId = nil
            }
        }

        mutating func categorySelectionChanged() {
            subcategoryId = nil
            if selectedCategoryKind != .transfer {
                destinationAccountId = nil
            }
        }

        mutating func refundSelectionChanged() {
            guard let purchase = refundablePurchases.first(where: { $0.id == refundOfTransactionId })
            else { return }
            categoryId = purchase.categoryId
            subcategoryId = purchase.subcategoryId
        }

        private func refundablePurchases(
            accountId: UUID?,
            occurredAt: Date,
            excluding transactionId: UUID? = nil
        ) -> [Transaction] {
            guard let accountId else { return [] }
            return transactions
                .filter {
                    $0.accountId == accountId
                        && $0.id != transactionId
                        && $0.refundOfTransactionId == nil
                        && $0.destinationAccountId == nil
                        && $0.occurredAt <= occurredAt
                        && remainingRefundableAmount(for: $0) > 0
                }
                .sorted { $0.occurredAt > $1.occurredAt }
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
            var refundOfTransactionId: UUID?
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
                self.refundOfTransactionId = state.refundOfTransactionId
                self.notes = state.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case cancelButtonTapped
        case discardChangesConfirmed
        case discardChangesDismissed
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

            case .binding(\.refundOfTransactionId):
                state.refundSelectionChanged()
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
