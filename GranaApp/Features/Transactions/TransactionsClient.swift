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
    var loadSnapshot: @Sendable () async throws -> TransactionsSnapshot
    var loadNextPage: @Sendable (_ cursor: TransactionRemotePageCursor) async throws -> TransactionRemotePage
    var create: @Sendable (_ input: TransactionMutationInput) async throws -> Void
    var update: @Sendable (_ transactionId: UUID, _ input: TransactionMutationInput) async throws -> Void
    var delete: @Sendable (_ transactionId: UUID) async throws -> Void

    static func live(container: AppContainer, pageSize: Int = 50) -> TransactionsClient {
        TransactionsClient(
            loadSnapshot: {
                async let transactionPage = container.remoteTransactions.loadPage(
                    cursor: nil,
                    limit: pageSize
                )
                async let accountSnapshot = container.remoteAccounts.load()
                async let statementSnapshot = container.remoteStatements.load()
                async let categoryCatalog = container.categoryCatalog.load()
                async let institutionCatalog = container.institutionCatalog.load()
                let (page, accounts, statements, categories, institutions) = try await (
                    transactionPage,
                    accountSnapshot,
                    statementSnapshot,
                    categoryCatalog,
                    institutionCatalog
                )

                return TransactionsSnapshot(
                    page: page,
                    accounts: accounts.accounts,
                    institutions: institutions,
                    bankDetails: accounts.bankDetails,
                    creditCards: accounts.creditCards,
                    categories: categories,
                    statements: statements.statements,
                    statementPayments: statements.payments
                )
            },
            loadNextPage: { cursor in
                try await container.remoteTransactions.loadPage(cursor: cursor, limit: pageSize)
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
}

extension TransactionsClient: DependencyKey {
    static let liveValue = TransactionsClient(
        loadSnapshot: { .empty },
        loadNextPage: { _ in .empty },
        create: { _ in },
        update: { _, _ in },
        delete: { _ in }
    )

    static let testValue = TransactionsClient(
        loadSnapshot: unimplemented("TransactionsClient.loadSnapshot"),
        loadNextPage: unimplemented("TransactionsClient.loadNextPage"),
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
    }

    static let testValue = NoticeClient(
        report: unimplemented("NoticeClient.report")
    )
}

extension DependencyValues {
    var noticeClient: NoticeClient {
        get { self[NoticeClient.self] }
        set { self[NoticeClient.self] = newValue }
    }
}
