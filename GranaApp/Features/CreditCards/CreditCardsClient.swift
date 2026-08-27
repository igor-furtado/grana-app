import ComposableArchitecture
import Foundation

struct CreditCardListItem: Equatable, Identifiable {
    let account: Account
    let institution: Institution?
    let details: CreditCardDetails?
    let currentBalance: Decimal

    var id: UUID {
        account.id
    }
}

struct CreditCardListSnapshot: Equatable {
    var items: [CreditCardListItem]
    var institutions: [Institution]

    static let empty = CreditCardListSnapshot(items: [], institutions: [])
}

struct CreditCardStatementsSnapshot: Equatable {
    let card: CreditCardListItem
    let statements: [Statement]
    let projections: [StatementWindow]
}

struct StatementTransactionRow: Equatable, Identifiable {
    let transaction: Transaction
    let category: Category?

    var id: UUID {
        transaction.id
    }
}

struct StatementTransactionsSnapshot: Equatable {
    let rows: [StatementTransactionRow]
}

struct CreditCardMutationInput: Equatable {
    var institutionId: UUID?
    var currency: String = "BRL"
    var cardLastFour: String
    var creditLimit: Decimal?
    var statementClosingDay: Int
    var paymentDueDay: Int
}

struct CreditCardsClient {
    var loadList: @Sendable () async throws -> CreditCardListSnapshot
    var loadStatements: @Sendable (_ card: CreditCardListItem) async throws -> CreditCardStatementsSnapshot
    var loadStatementTransactions: @Sendable (_ statementId: UUID) async throws -> StatementTransactionsSnapshot
    var updateStatementDates: @Sendable (_ statementId: UUID, _ closingDate: Date, _ dueDate: Date) async throws
        -> StatementDateUpdateResult
    var create: @Sendable (_ input: CreditCardMutationInput) async throws -> Void
    var update: @Sendable (
        _ cardId: UUID,
        _ archived: Bool,
        _ input: CreditCardMutationInput,
        _ cycleEffectiveFrom: Date?
    ) async throws -> Void
    var setArchived: @Sendable (_ cardId: UUID, _ archived: Bool) async throws -> Void
    var delete: @Sendable (_ cardId: UUID) async throws -> Void

    static func live(container: AppContainer) -> CreditCardsClient {
        CreditCardsClient(
            loadList: {
                async let accountSnapshot = container.remoteAccounts.load()
                async let institutionCatalog = container.institutionCatalog.load()
                async let statementSnapshot = container.remoteStatements.load()
                let (accounts, institutions, statements) = try await (
                    accountSnapshot,
                    institutionCatalog,
                    statementSnapshot
                )

                let items = accounts.accounts
                    .filter { $0.type == .creditCard }
                    .map { account in
                        CreditCardListItem(
                            account: account,
                            institution: institutions.first { $0.id == account.institutionId },
                            details: accounts.creditCards.first { $0.accountId == account.id },
                            currentBalance: currentBalance(
                                accountId: account.id,
                                statements: statements.statements
                            )
                        )
                    }

                return CreditCardListSnapshot(items: items, institutions: institutions)
            },
            loadStatements: { card in
                let snapshot = try await container.remoteStatements.load()
                let statements = snapshot.statements
                    .filter { $0.accountId == card.id }
                    .sorted { $0.closingDate < $1.closingDate }
                return CreditCardStatementsSnapshot(
                    card: card,
                    statements: statements,
                    projections: projectedCycles(
                        details: card.details,
                        statements: statements
                    )
                )
            },
            loadStatementTransactions: { statementId in
                async let transactions = container.remoteStatements.loadTransactions(statementId: statementId)
                async let categories = container.categoryCatalog.load()
                let (loadedTransactions, loadedCategories) = try await (transactions, categories)
                let categoriesById = Dictionary(uniqueKeysWithValues: loadedCategories.map { ($0.id, $0) })
                return StatementTransactionsSnapshot(
                    rows: loadedTransactions.map { transaction in
                        StatementTransactionRow(
                            transaction: transaction,
                            category: categoriesById[transaction.categoryId]
                        )
                    }
                )
            },
            updateStatementDates: { statementId, closingDate, dueDate in
                try await container.remoteStatements.updateDates(
                    statementId: statementId,
                    closingDate: closingDate,
                    dueDate: dueDate
                )
            },
            create: { input in
                try await container.remoteAccounts.create(
                    input: accountMutationInput(from: input, archived: false)
                )
            },
            update: { cardId, archived, input, cycleEffectiveFrom in
                try await container.remoteAccounts.update(
                    accountId: cardId,
                    input: accountMutationInput(from: input, archived: archived),
                    cycleEffectiveFrom: cycleEffectiveFrom
                )
            },
            setArchived: { cardId, archived in
                let snapshot = try await container.remoteAccounts.load()
                guard let account = snapshot.accounts.first(where: { $0.id == cardId }),
                      let details = snapshot.creditCards.first(where: { $0.accountId == cardId })
                else { return }
                try await container.remoteAccounts.update(
                    accountId: cardId,
                    input: accountMutationInput(
                        from: CreditCardMutationInput(
                            institutionId: account.institutionId,
                            currency: account.currency,
                            cardLastFour: details.cardLastFour,
                            creditLimit: details.creditLimit,
                            statementClosingDay: details.statementClosingDay,
                            paymentDueDay: details.paymentDueDay
                        ),
                        archived: archived
                    ),
                    cycleEffectiveFrom: nil
                )
            },
            delete: { cardId in
                try await container.remoteAccounts.delete(accountId: cardId)
            }
        )
    }

    private static func accountMutationInput(
        from input: CreditCardMutationInput,
        archived: Bool
    ) -> AccountMutationInput {
        AccountMutationInput(
            type: .creditCard,
            initialBalance: 0,
            archived: archived,
            institutionId: input.institutionId,
            currency: input.currency,
            bankDetails: nil,
            creditCardDetails: CreditCardDetailsInput(
                cardLastFour: input.cardLastFour,
                creditLimit: input.creditLimit,
                statementClosingDay: input.statementClosingDay,
                paymentDueDay: input.paymentDueDay
            )
        )
    }

    private static func currentBalance(
        accountId: UUID,
        statements: [Statement]
    ) -> Decimal {
        statements
            .filter { $0.accountId == accountId }
            .reduce(Decimal.zero) { $0 + $1.remainingAmount }
    }

    private static func projectedCycles(
        details: CreditCardDetails?,
        statements: [Statement],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [StatementWindow] {
        guard let details else { return [] }
        let start: Date = {
            if let last = statements.last {
                return calendar.date(byAdding: .day, value: 1, to: last.closingDate) ?? now
            }
            return now
        }()

        var cycles: [StatementWindow] = []
        var cursor = start
        for _ in 0 ..< 2 {
            let window = StatementWindow.resolve(
                closingDay: details.statementClosingDay,
                paymentDueDay: details.paymentDueDay,
                on: cursor,
                calendar: calendar
            )
            cycles.append(window)
            cursor = calendar.date(byAdding: .day, value: 1, to: window.closingDate) ?? cursor
        }
        return cycles
    }
}

extension CreditCardsClient: DependencyKey {
    static let liveValue = CreditCardsClient(
        loadList: { CreditCardListSnapshot(items: [], institutions: []) },
        loadStatements: { card in
            CreditCardStatementsSnapshot(card: card, statements: [], projections: [])
        },
        loadStatementTransactions: { _ in
            StatementTransactionsSnapshot(rows: [])
        },
        updateStatementDates: { statementId, _, _ in
            StatementDateUpdateResult(
                statementId: statementId,
                movedTransactionCount: 0,
                enteredTransactionCount: 0,
                exitedTransactionCount: 0,
                affectedStatementCount: 0,
                paymentDifferenceStatementCount: 0
            )
        },
        create: { _ in },
        update: { _, _, _, _ in },
        setArchived: { _, _ in },
        delete: { _ in }
    )

    static let testValue = CreditCardsClient(
        loadList: unimplemented("CreditCardsClient.loadList"),
        loadStatements: unimplemented("CreditCardsClient.loadStatements"),
        loadStatementTransactions: unimplemented("CreditCardsClient.loadStatementTransactions"),
        updateStatementDates: unimplemented("CreditCardsClient.updateStatementDates"),
        create: unimplemented("CreditCardsClient.create"),
        update: unimplemented("CreditCardsClient.update"),
        setArchived: unimplemented("CreditCardsClient.setArchived"),
        delete: unimplemented("CreditCardsClient.delete")
    )
}

extension DependencyValues {
    var creditCardsClient: CreditCardsClient {
        get { self[CreditCardsClient.self] }
        set { self[CreditCardsClient.self] = newValue }
    }
}
