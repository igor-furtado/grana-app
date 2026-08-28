import ComposableArchitecture
import Foundation

enum TransactionsHeaderPresentedFilter: Equatable {
    case bank
    case category
    case period
    case kind
}

enum TransactionKindFilter: CaseIterable, Equatable, Identifiable {
    case all
    case expense
    case income
    case transfer

    var id: Self {
        self
    }

    var name: String {
        switch self {
        case .all: "Todas"
        case .expense: "Despesas"
        case .income: "Receitas"
        case .transfer: "Transferências"
        }
    }

    func matches(_ transaction: Transaction, categoriesById: [UUID: Category]) -> Bool {
        let kind = categoriesById[transaction.categoryId]?.kind
        return self == .all
            || self == .expense && kind == .expense
            || self == .income && kind == .income
            || self == .transfer && kind == .transfer
    }
}

enum TransactionCategoryFilter: Equatable {
    case all
    case category(UUID)

    func name(feature: TransactionListFeature.State) -> String {
        if case let .category(id) = self {
            return feature.category(for: id)?.name ?? "Categoria"
        }
        return "Todas categorias"
    }

    func matches(_ transaction: Transaction) -> Bool {
        if case let .category(id) = self {
            return transaction.categoryId == id || transaction.subcategoryId == id
        }
        return true
    }
}

enum TransactionPeriodFilter: CaseIterable, Equatable, Identifiable {
    case month
    case quarter
    case year
    case all

    var id: Self {
        self
    }

    var name: String {
        switch self {
        case .month: "Este mês"
        case .quarter: "90 dias"
        case .year: "Este ano"
        case .all: "Tudo"
        }
    }

    func matches(_ transaction: Transaction, calendar: Calendar = .current, today: Date = Date()) -> Bool {
        switch self {
        case .all:
            return true
        case .month:
            return calendar.dateInterval(of: .month, for: today)?.contains(transaction.occurredAt) ?? true
        case .year:
            return calendar.dateInterval(of: .year, for: today)?.contains(transaction.occurredAt) ?? true
        case .quarter:
            guard let start = calendar.date(byAdding: .day, value: -90, to: today) else { return true }
            return transaction.occurredAt >= start && transaction.occurredAt <= today
        }
    }
}

enum TransactionBankFilter: Equatable {
    case all
    case bank(UUID)

    func name(feature: TransactionListFeature.State) -> String {
        if case let .bank(id) = self {
            return feature.institution(for: id)?.name ?? "Banco"
        }
        return "Todos bancos"
    }

    func matches(_ transaction: Transaction, accountsById: [UUID: Account]) -> Bool {
        if case let .bank(id) = self {
            return accountsById[transaction.accountId]?.institutionId == id
        }
        return true
    }
}

enum TransactionsTableSort: Equatable {
    case institutionAscending
    case institutionDescending
    case occurredAtAscending
    case occurredAtDescending
    case descriptionAscending
    case descriptionDescending
    case categoryAscending
    case categoryDescending
    case amountAscending
    case amountDescending
}

struct TransactionsTableQuery: Equatable {
    var kindFilter: TransactionKindFilter = .all
    var categoryFilter: TransactionCategoryFilter = .all
    var periodFilter: TransactionPeriodFilter = .month
    var bankFilter: TransactionBankFilter = .all
    var sort: TransactionsTableSort = .occurredAtDescending

    func matches(
        _ transaction: Transaction,
        accountsById: [UUID: Account],
        categoriesById: [UUID: Category],
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> Bool {
        if !kindFilter.matches(transaction, categoriesById: categoriesById) {
            return false
        }
        if !periodFilter.matches(transaction, calendar: calendar, today: today) {
            return false
        }
        if !bankFilter.matches(transaction, accountsById: accountsById) {
            return false
        }
        if !categoryFilter.matches(transaction) {
            return false
        }
        return true
    }

    func areInIncreasingOrder(
        _ lhs: Transaction,
        _ rhs: Transaction,
        accountsById: [UUID: Account],
        institutionsById: [UUID: Institution],
        categoriesById: [UUID: Category]
    ) -> Bool {
        switch sort {
        case .institutionAscending:
            compareStrings(
                institutionName(for: lhs, accountsById: accountsById, institutionsById: institutionsById),
                institutionName(for: rhs, accountsById: accountsById, institutionsById: institutionsById),
                lhs: lhs,
                rhs: rhs
            )
        case .institutionDescending:
            compareStrings(
                institutionName(for: rhs, accountsById: accountsById, institutionsById: institutionsById),
                institutionName(for: lhs, accountsById: accountsById, institutionsById: institutionsById),
                lhs: lhs,
                rhs: rhs
            )
        case .occurredAtAscending:
            compareDates(lhs.occurredAt, rhs.occurredAt, lhs: lhs, rhs: rhs, reversed: false)
        case .occurredAtDescending:
            compareDates(lhs.occurredAt, rhs.occurredAt, lhs: lhs, rhs: rhs, reversed: true)
        case .descriptionAscending:
            compareStrings(lhs.description, rhs.description, lhs: lhs, rhs: rhs)
        case .descriptionDescending:
            compareStrings(rhs.description, lhs.description, lhs: lhs, rhs: rhs)
        case .categoryAscending:
            compareStrings(
                categoryName(for: lhs, categoriesById: categoriesById),
                categoryName(for: rhs, categoriesById: categoriesById),
                lhs: lhs,
                rhs: rhs
            )
        case .categoryDescending:
            compareStrings(
                categoryName(for: rhs, categoriesById: categoriesById),
                categoryName(for: lhs, categoriesById: categoriesById),
                lhs: lhs,
                rhs: rhs
            )
        case .amountAscending:
            compareAmounts(lhs.amount, rhs.amount, lhs: lhs, rhs: rhs, reversed: false)
        case .amountDescending:
            compareAmounts(lhs.amount, rhs.amount, lhs: lhs, rhs: rhs, reversed: true)
        }
    }

    private func institutionName(
        for transaction: Transaction,
        accountsById: [UUID: Account],
        institutionsById: [UUID: Institution]
    ) -> String {
        guard let account = accountsById[transaction.accountId],
              let institutionId = account.institutionId
        else {
            return ""
        }
        return institutionsById[institutionId]?.name ?? ""
    }

    private func categoryName(
        for transaction: Transaction,
        categoriesById: [UUID: Category]
    ) -> String {
        categoriesById[transaction.categoryId]?.name ?? ""
    }

    private func compareStrings(
        _ lhsValue: String,
        _ rhsValue: String,
        lhs: Transaction,
        rhs: Transaction
    ) -> Bool {
        let order = lhsValue.localizedStandardCompare(rhsValue)
        if order == .orderedSame {
            return compareDates(lhs.occurredAt, rhs.occurredAt, lhs: lhs, rhs: rhs, reversed: true)
        }
        return order == .orderedAscending
    }

    private func compareDates(
        _ lhsValue: Date,
        _ rhsValue: Date,
        lhs: Transaction,
        rhs: Transaction,
        reversed: Bool
    ) -> Bool {
        if lhsValue == rhsValue {
            return lhs.createdAt == rhs.createdAt
                ? lhs.id.uuidString < rhs.id.uuidString
                : lhs.createdAt > rhs.createdAt
        }
        return reversed ? lhsValue > rhsValue : lhsValue < rhsValue
    }

    private func compareAmounts(
        _ lhsValue: Decimal,
        _ rhsValue: Decimal,
        lhs: Transaction,
        rhs: Transaction,
        reversed: Bool
    ) -> Bool {
        if lhsValue == rhsValue {
            return compareDates(lhs.occurredAt, rhs.occurredAt, lhs: lhs, rhs: rhs, reversed: true)
        }
        return reversed ? lhsValue > rhsValue : lhsValue < rhsValue
    }
}

@Reducer
struct TransactionListFeature {
    @ObservableState
    struct State: Equatable {
        var transactions: [Transaction] = []
        var accounts: [Account] = []
        var institutions: [Institution] = []
        var bankDetails: [BankAccountDetails] = []
        var creditCards: [CreditCardDetails] = []
        var categories: [Category] = []
        var statements: [Statement] = []
        var statementPayments: [StatementPayment] = []
        var supportsAdvancedCardRules = true
        var isLoading = false

        var searchText = ""
        var kindFilter: TransactionKindFilter = .all
        var categoryFilter: TransactionCategoryFilter = .all
        var periodFilter: TransactionPeriodFilter = .month
        var bankFilter: TransactionBankFilter = .all
        var tableSort: TransactionsTableSort = .occurredAtDescending
        var presentedHeaderFilter: TransactionsHeaderPresentedFilter?

        var rootCategories: [Category] {
            categories.filter { $0.parentId == nil }
        }

        var sortedRootCategories: [Category] {
            rootCategories.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        var availableBanks: [Institution] {
            let ids = Set(accounts.compactMap(\.institutionId))
            return institutions.filter { ids.contains($0.id) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        var bankFilterName: String {
            bankFilter.name(feature: self)
        }

        var categoryFilterName: String {
            categoryFilter.name(feature: self)
        }

        var loadQuery: TransactionsTableQuery {
            TransactionsTableQuery(
                kindFilter: kindFilter,
                categoryFilter: categoryFilter,
                periodFilter: periodFilter,
                bankFilter: bankFilter,
                sort: tableSort
            )
        }

        private var accountsById: [UUID: Account] {
            Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        }

        private var institutionsById: [UUID: Institution] {
            Dictionary(uniqueKeysWithValues: institutions.map { ($0.id, $0) })
        }

        private var categoriesById: [UUID: Category] {
            Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        }

        func visibleTransactions(calendar: Calendar = .current, today: Date = Date()) -> [Transaction] {
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let needle = trimmed.lowercased()

            return transactions
                .filter { transaction in
                    guard loadQuery.matches(
                        transaction,
                        accountsById: accountsById,
                        categoriesById: categoriesById,
                        calendar: calendar,
                        today: today
                    ) else {
                        return false
                    }

                    guard !needle.isEmpty else { return true }
                    if transaction.description.lowercased().contains(needle) { return true }
                    if categorySummary(for: transaction).lowercased().contains(needle) { return true }
                    if accountName(for: transaction).lowercased().contains(needle) { return true }
                    return false
                }
                .sorted { lhs, rhs in
                    loadQuery.areInIncreasingOrder(
                        lhs,
                        rhs,
                        accountsById: accountsById,
                        institutionsById: institutionsById,
                        categoriesById: categoriesById
                    )
                }
        }

        func transactionsCountText(calendar: Calendar = .current, today: Date = Date()) -> String {
            let visible = visibleTransactions(calendar: calendar, today: today).count
            let total = transactions.count
            return visible == total ? "\(visible) transações" : "\(visible) de \(total) transações"
        }

        func deletePreview(for transaction: Transaction) -> String {
            let impact = deleteImpactMessage(for: transaction)
            guard !impact.isEmpty else {
                return deleteSummary(for: transaction)
            }
            return deleteSummary(for: transaction) + "\n\n" + impact
        }

        func deleteSummary(for transaction: Transaction) -> String {
            "\(transaction.description) - \(transaction.amount.formatted(.currency(code: "BRL")))"
        }

        func deleteImpactMessage(for transaction: Transaction) -> String {
            var messages: [String] = []
            let sourceIsCard = account(for: transaction.accountId)?.type == .creditCard
            let destinationIsCard = transaction.destinationAccountId.flatMap(account(for:))?.type == .creditCard
            if sourceIsCard {
                messages.append(
                    "A fatura desta transação será recalculada. Pagamentos já registrados permanecem nas faturas onde foram aplicados."
                )
            } else if destinationIsCard {
                messages.append(
                    "A aplicação deste pagamento será removida da fatura onde foi registrada."
                )
            }

            let linkedRefundCount = transactions.filter {
                $0.refundOfTransactionId == transaction.id
            }.count
            if linkedRefundCount > 0 {
                let refundText = linkedRefundCount == 1
                    ? "1 estorno vinculado"
                    : "\(linkedRefundCount) estornos vinculados"
                messages.append("A exclusão será rejeitada enquanto houver \(refundText).")
            }
            return messages.joined(separator: "\n")
        }

        func category(for id: UUID) -> Category? {
            categories.first { $0.id == id }
        }

        func icon(for categoryId: UUID) -> CategoryIcon? {
            guard let selectedCategory = category(for: categoryId) else { return nil }
            if let icon = selectedCategory.icon { return icon }
            if let parentId = selectedCategory.parentId, let parent = category(for: parentId) {
                return parent.icon
            }
            return nil
        }

        func account(for id: UUID) -> Account? {
            accounts.first { $0.id == id }
        }

        func supportsBasicMutation(for transaction: Transaction) -> Bool {
            if supportsAdvancedCardRules {
                return true
            }

            if transaction.statementId != nil || transaction.refundOfTransactionId != nil {
                return false
            }

            if account(for: transaction.accountId)?.type == .creditCard {
                return false
            }

            if let destinationAccountId = transaction.destinationAccountId,
               account(for: destinationAccountId)?.type == .creditCard {
                return false
            }

            return true
        }

        func institution(for id: UUID) -> Institution? {
            institutions.first { $0.id == id }
        }

        func displayName(for account: Account) -> String {
            Account.displayName(
                for: account,
                institutions: institutions,
                bankAccounts: bankDetails,
                creditCards: creditCards
            )
        }

        func subcategoryName(for transaction: Transaction) -> String? {
            guard let subcategoryId = transaction.subcategoryId else { return nil }
            return category(for: subcategoryId)?.name
        }

        func categorySummary(for transaction: Transaction) -> String {
            let category = categoryName(for: transaction)
            guard let subcategory = subcategoryName(for: transaction) else {
                return category
            }
            return "\(category) · \(subcategory)"
        }

        func accountName(for transaction: Transaction) -> String {
            account(for: transaction.accountId).map { displayName(for: $0) } ?? "-"
        }

        func categoryName(for transaction: Transaction) -> String {
            category(for: transaction.categoryId)?.name ?? "-"
        }

        func institutionKind(for transaction: Transaction) -> InstitutionKind {
            guard let account = account(for: transaction.accountId),
                  let institutionId = account.institutionId,
                  let institution = institution(for: institutionId)
            else {
                return .other
            }
            return institution.kind
        }

        mutating func apply(_ snapshot: TransactionsSnapshot) {
            transactions = snapshot.page.transactions
            accounts = snapshot.accounts
            bankDetails = snapshot.bankDetails
            creditCards = snapshot.creditCards
            statements = snapshot.statements
            statementPayments = snapshot.statementPayments
            categories = snapshot.categories
            institutions = snapshot.institutions
        }

        mutating func clearLoadedData() {
            transactions = []
            statements = []
            statementPayments = []
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case headerFilterPresented(TransactionsHeaderPresentedFilter?)
        case periodFilterSelected(TransactionPeriodFilter)
        case kindFilterSelected(TransactionKindFilter)
        case bankFilterSelected(TransactionBankFilter)
        case categoryFilterSelected(TransactionCategoryFilter)
        case tableSortSelected(TransactionsTableSort)
        case addButtonTapped
        case editButtonTapped(Transaction)
        case deleteButtonTapped(Transaction)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case createRequested
        case editRequested(Transaction)
        case deleteRequested(Transaction)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .headerFilterPresented(filter):
                state.presentedHeaderFilter = filter
                return .none

            case let .periodFilterSelected(filter):
                state.periodFilter = filter
                state.presentedHeaderFilter = nil
                return .none

            case let .kindFilterSelected(filter):
                state.kindFilter = filter
                state.presentedHeaderFilter = nil
                return .none

            case let .bankFilterSelected(filter):
                state.bankFilter = filter
                state.presentedHeaderFilter = nil
                return .none

            case let .categoryFilterSelected(filter):
                state.categoryFilter = filter
                state.presentedHeaderFilter = nil
                return .none

            case let .tableSortSelected(sort):
                state.tableSort = sort
                return .none

            case .addButtonTapped:
                return .send(.delegate(.createRequested))

            case let .editButtonTapped(transaction):
                return .send(.delegate(.editRequested(transaction)))

            case let .deleteButtonTapped(transaction):
                return .send(.delegate(.deleteRequested(transaction)))

            case .delegate:
                return .none
            }
        }
    }
}
