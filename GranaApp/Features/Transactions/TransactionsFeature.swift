import ComposableArchitecture
import Foundation
import SwiftUI

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

    func matches(_ transaction: Transaction, feature: TransactionsFeature.State) -> Bool {
        let kind = feature.category(for: transaction.categoryId)?.kind
        return self == .all
            || self == .expense && kind == .expense
            || self == .income && kind == .income
            || self == .transfer && kind == .transfer
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

    func name(feature: TransactionsFeature.State) -> String {
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

    func name(feature: TransactionsFeature.State) -> String {
        if case let .bank(id) = self {
            return feature.institution(for: id)?.name ?? "Banco"
        }
        return "Todos bancos"
    }

    func matches(_ transaction: Transaction, feature: TransactionsFeature.State) -> Bool {
        if case let .bank(id) = self {
            return feature.account(for: transaction.accountId)?.institutionId == id
        }
        return true
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
struct TransactionsFeature {
    @Reducer
    enum Destination {
        case editForm(TransactionFormFeature)
    }

    @CasePathable
    enum ConfirmationDialog: Equatable {
        case deleteConfirmed
    }

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
        var isLoading = false
        var hasLoaded = false
        var supportsAdvancedCardRules = true

        var searchText = ""
        var kindFilter: TransactionKindFilter = .all
        var categoryFilter: TransactionCategoryFilter = .all
        var periodFilter: TransactionPeriodFilter = .month
        var bankFilter: TransactionBankFilter = .all
        var tableSort: TransactionsTableSort = .occurredAtDescending
        var presentedHeaderFilter: TransactionsHeaderPresentedFilter?
        var pendingDelete: Transaction?

        @Presents var destination: Destination.State?
        @Presents var confirmationDialog: ConfirmationDialogState<ConfirmationDialog>?

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

        func filtered(calendar: Calendar = .current, today: Date = Date()) -> [Transaction] {
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let needle = trimmed.lowercased()
            return transactions.filter { transaction in
                guard !needle.isEmpty else { return true }
                if transaction.description.lowercased().contains(needle) { return true }
                if categorySummary(for: transaction).lowercased().contains(needle) {
                    return true
                }
                if accountName(for: transaction).lowercased().contains(needle) {
                    return true
                }
                return false
            }
        }

        func loadQuery() -> TransactionsTableQuery {
            TransactionsTableQuery(
                kindFilter: kindFilter,
                categoryFilter: categoryFilter,
                periodFilter: periodFilter,
                bankFilter: bankFilter,
                sort: tableSort
            )
        }

        func transactionsCountText(calendar: Calendar = .current, today: Date = Date()) -> String {
            let visible = filtered(calendar: calendar, today: today).count
            let total = transactions.count
            return visible == total ? "\(visible) transações" : "\(visible) de \(total) transações"
        }

        func deletePreview(for transaction: Transaction) -> String {
            var message = "\(transaction.description) — \(transaction.amount.formatted(.currency(code: "BRL")))"
            let affectsCard = account(for: transaction.accountId)?.type == .creditCard
                || transaction.destinationAccountId.flatMap(account(for:))?.type == .creditCard
            if affectsCard {
                message += "\n\nFaturas afetadas serão recalculadas. Pagamentos vinculados a outras faturas permanecem onde foram registrados."
            }
            let linkedRefundCount = transactions.filter {
                $0.refundOfTransactionId == transaction.id
            }.count
            if linkedRefundCount > 0 {
                message += "\nA exclusão será rejeitada enquanto houver \(linkedRefundCount) estorno(s) vinculado(s)."
            }
            return message
        }

        func category(for id: UUID) -> Category? {
            categories.first { $0.id == id }
        }

        func icon(for categoryId: UUID) -> CategoryIcon? {
            guard let selectedCategory = category(for: categoryId) else { return nil }
            if let icon = selectedCategory.icon { return icon }
            if let parentId = selectedCategory.parentId {
                if let parent = category(for: parentId) {
                    return parent.icon
                }
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

            if let destinationAccountId = transaction.destinationAccountId {
                if account(for: destinationAccountId)?.type == .creditCard {
                    return false
                }
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

        func formState(existing: Transaction? = nil) -> TransactionFormFeature.State {
            TransactionFormFeature.State(
                existing: existing,
                transactions: transactions,
                accounts: accounts,
                institutions: institutions,
                bankDetails: bankDetails,
                creditCards: creditCards,
                categories: categories,
                statements: statements,
                statementPayments: statementPayments
            )
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
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case refresh
        case snapshotLoaded(TransactionsSnapshot)
        case loadFailed
        case headerFilterPresented(TransactionsHeaderPresentedFilter?)
        case periodFilterSelected(TransactionPeriodFilter)
        case kindFilterSelected(TransactionKindFilter)
        case bankFilterSelected(TransactionBankFilter)
        case categoryFilterSelected(TransactionCategoryFilter)
        case tableSortSelected(TransactionsTableSort)
        case editButtonTapped(Transaction)
        case deleteButtonTapped(Transaction)
        case destination(PresentationAction<Destination.Action>)
        case confirmationDialog(PresentationAction<ConfirmationDialog>)
    }

    @Dependency(\.transactionsClient) private var transactionsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .task:
                guard !state.hasLoaded else { return .none }
                return load(&state)

            case .refresh:
                return load(&state)

            case let .snapshotLoaded(snapshot):
                state.apply(snapshot)
                state.isLoading = false
                state.hasLoaded = true
                return .none

            case .loadFailed:
                state.transactions = []
                state.statements = []
                state.statementPayments = []
                state.isLoading = false
                state.hasLoaded = true
                return .none

            case let .headerFilterPresented(filter):
                state.presentedHeaderFilter = filter
                return .none

            case let .periodFilterSelected(filter):
                state.periodFilter = filter
                state.presentedHeaderFilter = nil
                return .send(.refresh)

            case let .kindFilterSelected(filter):
                state.kindFilter = filter
                state.presentedHeaderFilter = nil
                return .send(.refresh)

            case let .bankFilterSelected(filter):
                state.bankFilter = filter
                state.presentedHeaderFilter = nil
                return .send(.refresh)

            case let .categoryFilterSelected(filter):
                state.categoryFilter = filter
                state.presentedHeaderFilter = nil
                return .send(.refresh)

            case let .tableSortSelected(sort):
                state.tableSort = sort
                return .send(.refresh)

            case let .editButtonTapped(transaction):
                state.destination = .editForm(state.formState(existing: transaction))
                return .none

            case let .deleteButtonTapped(transaction):
                let message = state.deletePreview(for: transaction)
                state.pendingDelete = transaction
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("Apagar transação?")
                } actions: {
                    ButtonState(role: .destructive, action: .deleteConfirmed) {
                        TextState("Apagar")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancelar")
                    }
                } message: {
                    TextState(message)
                }
                return .none

            case .destination(.presented(.editForm(.delegate(.cancel)))):
                state.destination = nil
                return .none

            case .destination(.presented(.editForm(.delegate(.saved)))):
                state.destination = nil
                return .send(.refresh)

            case .destination:
                return .none

            case .confirmationDialog(.presented(.deleteConfirmed)):
                guard let transaction = state.pendingDelete else { return .none }
                let query = state.loadQuery()
                state.pendingDelete = nil
                return .run { send in
                    do {
                        try await transactionsClient.delete(transaction.id)
                        let snapshot = try await transactionsClient.loadSnapshot(query)
                        await send(.snapshotLoaded(snapshot))
                    } catch {
                        await noticeClient.report(error, nil)
                        await send(.loadFailed)
                    }
                }

            case .confirmationDialog:
                state.pendingDelete = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.isLoading = true
        let query = state.loadQuery()
        return .run { send in
            do {
                let snapshot = try await transactionsClient.loadSnapshot(query)
                await send(.snapshotLoaded(snapshot))
            } catch {
                await noticeClient.report(error, nil)
                await send(.loadFailed)
            }
        }
    }
}

extension TransactionsFeature.Destination.State: Equatable {}
