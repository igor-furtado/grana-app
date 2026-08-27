import ComposableArchitecture
import Foundation

struct TransactionsSnapshot {
    var page: TransactionRemotePage
    var accounts: [Account]
    var institutions: [Institution]
    var bankDetails: [BankAccountDetails]
    var creditCards: [CreditCardDetails]
    var categories: [Category]
    var statements: [Statement]
    var statementPayments: [StatementPayment]

    static let empty = TransactionsSnapshot(
        page: .empty,
        accounts: [],
        institutions: [],
        bankDetails: [],
        creditCards: [],
        categories: [],
        statements: [],
        statementPayments: []
    )
}

struct TransactionsClient {
    var loadSnapshot: @Sendable (_ query: TransactionsTableQuery) async throws -> TransactionsSnapshot
    var create: @Sendable (_ input: TransactionMutationInput) async throws -> Void
    var update: @Sendable (_ transactionId: UUID, _ input: TransactionMutationInput) async throws -> Void
    var delete: @Sendable (_ transactionId: UUID) async throws -> Void

    static func live(container: AppContainer) -> TransactionsClient {
        TransactionsClient(
            loadSnapshot: { query in
                async let allTransactions = container.remoteTransactions.loadAll()
                async let accountSnapshot = container.remoteAccounts.load()
                async let statementSnapshot = container.remoteStatements.load()
                async let categoryCatalog = container.categoryCatalog.load()
                async let institutionCatalog = container.institutionCatalog.load()
                let (transactions, accounts, statements, categories, institutions) = try await (
                    allTransactions,
                    accountSnapshot,
                    statementSnapshot,
                    categoryCatalog,
                    institutionCatalog
                )
                let filteredTransactions = applyQuery(
                    query,
                    transactions: transactions,
                    accounts: accounts.accounts,
                    institutions: institutions,
                    categories: categories
                )

                return TransactionsSnapshot(
                    page: TransactionRemotePage(transactions: filteredTransactions, nextCursor: nil),
                    accounts: accounts.accounts,
                    institutions: institutions,
                    bankDetails: accounts.bankDetails,
                    creditCards: accounts.creditCards,
                    categories: categories,
                    statements: statements.statements,
                    statementPayments: statements.payments
                )
            },
            create: { input in
                try await container.remoteTransactions.create(input: input)
            },
            update: { transactionId, input in
                try await container.remoteTransactions.update(transactionId: transactionId, input: input)
            },
            delete: { transactionId in
                try await container.remoteTransactions.delete(transactionId: transactionId)
            }
        )
    }

    private static func applyQuery(
        _ query: TransactionsTableQuery,
        transactions: [Transaction],
        accounts: [Account],
        institutions: [Institution],
        categories: [Category]
    ) -> [Transaction] {
        let accountById = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let institutionById = Dictionary(uniqueKeysWithValues: institutions.map { ($0.id, $0) })
        let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        return transactions
            .filter { transaction in
                query.matches(
                    transaction,
                    accountsById: accountById,
                    categoriesById: categoryById
                )
            }
            .sorted { lhs, rhs in
                query.areInIncreasingOrder(
                    lhs,
                    rhs,
                    accountsById: accountById,
                    institutionsById: institutionById,
                    categoriesById: categoryById
                )
            }
    }
}

extension TransactionsClient: DependencyKey {
    static let liveValue = TransactionsClient(
        loadSnapshot: { _ in
            TransactionsSnapshot(
                page: .empty,
                accounts: [],
                institutions: [],
                bankDetails: [],
                creditCards: [],
                categories: [],
                statements: [],
                statementPayments: []
            )
        },
        create: { _ in },
        update: { _, _ in },
        delete: { _ in }
    )

    static let testValue = TransactionsClient(
        loadSnapshot: unimplemented("TransactionsClient.loadSnapshot"),
        create: unimplemented("TransactionsClient.create"),
        update: unimplemented("TransactionsClient.update"),
        delete: unimplemented("TransactionsClient.delete")
    )
}

extension DependencyValues {
    var transactionsClient: TransactionsClient {
        get { self[TransactionsClient.self] }
        set { self[TransactionsClient.self] = newValue }
    }
}

struct NoticeClient {
    var report: @Sendable (_ error: any Error, _ title: String?) async -> Void
    var info: @Sendable (_ title: String, _ message: String?) async -> Void
    var success: @Sendable (_ title: String, _ message: String?) async -> Void
}

extension NoticeClient: DependencyKey {
    static let liveValue = NoticeClient { error, title in
        await MainActor.run {
            if let title {
                NoticeCenter.shared.report(error, title: title)
            } else {
                NoticeCenter.shared.report(error)
            }
        }
    } info: { title, message in
        await MainActor.run {
            _ = NoticeCenter.shared.info(title: title, message: message)
        }
    } success: { title, message in
        await MainActor.run {
            _ = NoticeCenter.shared.success(title: title, message: message)
        }
    }

    static let testValue = NoticeClient(
        report: unimplemented("NoticeClient.report"),
        info: unimplemented("NoticeClient.info"),
        success: unimplemented("NoticeClient.success")
    )
}

extension DependencyValues {
    var noticeClient: NoticeClient {
        get { self[NoticeClient.self] }
        set { self[NoticeClient.self] = newValue }
    }
}
