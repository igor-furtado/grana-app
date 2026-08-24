import Foundation
import Supabase

nonisolated struct StatementRemoteSnapshot: Sendable {
    var statements: [Statement]
    var payments: [StatementPayment]

    static let empty = StatementRemoteSnapshot(
        statements: [],
        payments: []
    )
}

protocol StatementRemoteRepositoryProtocol: Sendable {
    func load() async throws -> StatementRemoteSnapshot
    func loadTransactions(statementId: UUID) async throws -> [Transaction]
}

nonisolated enum StatementRemoteRepositoryError: UserFacingError, Equatable {
    case authenticationRequired

    var errorTitle: String {
        "Falha ao carregar faturas"
    }

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "É preciso entrar com sua conta para carregar faturas e pagamentos do cartão."
        }
    }
}

nonisolated struct StatementRecordRow: Decodable, Sendable {
    let id: UUID
    let accountId: UUID
    let closingDate: Date
    let dueDate: Date
    let netAmountCents: Int64
    let creditReceivedCents: Int64
    let paymentAppliedCents: Int64
    let settledAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case closingDate = "closing_date"
        case dueDate = "due_date"
        case netAmountCents = "net_amount_cents"
        case creditReceivedCents = "credit_received_cents"
        case paymentAppliedCents = "payment_applied_cents"
        case settledAt = "settled_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct StatementPaymentRecordRow: Decodable, Sendable {
    let id: UUID
    let statementId: UUID
    let transactionId: UUID
    let appliedAmountCents: Int64
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case statementId = "statement_id"
        case transactionId = "transaction_id"
        case appliedAmountCents = "applied_amount_cents"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

protocol StatementRemoteStore: Sendable {
    func fetchStatements() async throws -> [StatementRecordRow]
    func fetchStatementPayments() async throws -> [StatementPaymentRecordRow]
    func fetchTransactions(statementId: UUID) async throws -> [TransactionRecordRow]
}

actor SupabaseStatementRemoteStore: StatementRemoteStore {
    private let authClient: any AuthClientProtocol
    private let supabaseURL: String
    private let supabaseAnonKey: String
    private var client: SupabaseClient?

    init(
        authClient: any AuthClientProtocol,
        supabaseURL: String? = nil,
        supabaseAnonKey: String? = nil
    ) {
        self.authClient = authClient
        self.supabaseURL = supabaseURL ?? Config.supabaseURL
        self.supabaseAnonKey = supabaseAnonKey ?? Config.supabaseAnonKey
    }

    func fetchStatements() async throws -> [StatementRecordRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_list_statements")
            .execute()
            .value
    }

    func fetchStatementPayments() async throws -> [StatementPaymentRecordRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_list_statement_payments")
            .execute()
            .value
    }

    func fetchTransactions(statementId: UUID) async throws -> [TransactionRecordRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_list_statement_transactions", params: ListStatementTransactionsRequest(statementId: statementId))
            .execute()
            .value
    }

    private func resolvedClient() throws -> SupabaseClient {
        if let client {
            return client
        }

        let client = try SupabaseAuthenticatedClientFactory.makeClient(
            authClient: authClient,
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey
        )
        self.client = client
        return client
    }
}

final class StatementRemoteRepository: StatementRemoteRepositoryProtocol, Sendable {
    private let remoteStore: any StatementRemoteStore

    init(remoteStore: any StatementRemoteStore) {
        self.remoteStore = remoteStore
    }

    func load() async throws -> StatementRemoteSnapshot {
        async let statements = remoteStore.fetchStatements()
        async let payments = remoteStore.fetchStatementPayments()
        let (statementRows, paymentRows) = try await (statements, payments)
        return StatementRemoteSnapshot(
            statements: statementRows.map(Self.mapStatement),
            payments: paymentRows.map(Self.mapPayment)
        )
    }

    func loadTransactions(statementId: UUID) async throws -> [Transaction] {
        try await remoteStore
            .fetchTransactions(statementId: statementId)
            .map(TransactionRemoteRepository.mapTransaction)
    }

    private static func mapStatement(_ row: StatementRecordRow) -> Statement {
        Statement(
            id: row.id,
            accountId: row.accountId,
            closingDate: row.closingDate,
            dueDate: row.dueDate,
            netAmount: Converters.centsToDecimal(row.netAmountCents),
            creditReceived: Converters.centsToDecimal(row.creditReceivedCents),
            paymentApplied: Converters.centsToDecimal(row.paymentAppliedCents),
            settledAt: row.settledAt,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }

    private static func mapPayment(_ row: StatementPaymentRecordRow) -> StatementPayment {
        StatementPayment(
            id: row.id,
            statementId: row.statementId,
            transactionId: row.transactionId,
            appliedAmount: Converters.centsToDecimal(row.appliedAmountCents),
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }
}

struct StaticStatementRemoteRepository: StatementRemoteRepositoryProtocol {
    let snapshot: StatementRemoteSnapshot
    var transactionsByStatementId: [UUID: [Transaction]] = [:]

    func load() async throws -> StatementRemoteSnapshot {
        snapshot
    }

    func loadTransactions(statementId: UUID) async throws -> [Transaction] {
        transactionsByStatementId[statementId] ?? []
    }
}

struct AuthRequiredStatementRemoteRepository: StatementRemoteRepositoryProtocol {
    func load() async throws -> StatementRemoteSnapshot {
        throw StatementRemoteRepositoryError.authenticationRequired
    }

    func loadTransactions(statementId _: UUID) async throws -> [Transaction] {
        throw StatementRemoteRepositoryError.authenticationRequired
    }
}

nonisolated struct ListStatementTransactionsRequest: Encodable, Sendable {
    let pStatementId: UUID

    init(statementId: UUID) {
        pStatementId = statementId
    }

    enum CodingKeys: String, CodingKey {
        case pStatementId = "p_statement_id"
    }
}
