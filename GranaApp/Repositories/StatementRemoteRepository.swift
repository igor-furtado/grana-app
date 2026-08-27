import Foundation
import Supabase

nonisolated struct StatementRemoteSnapshot {
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
    func updateDates(statementId: UUID, closingDate: Date, dueDate: Date) async throws -> StatementDateUpdateResult
}

nonisolated enum StatementRemoteRepositoryError: UserFacingError, Equatable {
    case authenticationRequired
    case statementNotFound
    case invalidAccount
    case invalidStatementDates
    case statementClosingBeforePrevious
    case statementClosingAfterNext
    case statementClosingConflict
    case unexpectedResponse

    var errorTitle: String {
        switch self {
        case .authenticationRequired:
            "Falha ao carregar faturas"
        default:
            "Falha ao salvar datas da fatura"
        }
    }

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "É preciso entrar com sua conta para carregar faturas e pagamentos do cartão."
        case .statementNotFound:
            return "A fatura selecionada não está mais disponível."
        case .invalidAccount:
            return "A fatura selecionada não pertence a um cartão disponível."
        case .invalidStatementDates:
            return "A data de vencimento precisa ser posterior à data de fechamento."
        case .statementClosingBeforePrevious:
            return "A data de fechamento precisa ser posterior ao fechamento da fatura anterior."
        case .statementClosingAfterNext:
            return "A data de fechamento precisa ser anterior ao fechamento da próxima fatura."
        case .statementClosingConflict:
            return "Já existe outra fatura com essa data de fechamento."
        case .unexpectedResponse:
            return "A resposta do backend para faturas veio inválida."
        }
    }

    static func from(code: String?) -> StatementRemoteRepositoryError {
        switch code {
        case "authentication_required":
            .authenticationRequired
        case "statement_not_found":
            .statementNotFound
        case "invalid_account":
            .invalidAccount
        case "invalid_statement_dates":
            .invalidStatementDates
        case "statement_closing_before_previous":
            .statementClosingBeforePrevious
        case "statement_closing_after_next":
            .statementClosingAfterNext
        case "statement_closing_conflict":
            .statementClosingConflict
        default:
            .unexpectedResponse
        }
    }
}

nonisolated struct StatementDateUpdateResult: Equatable {
    let statementId: UUID
    let movedTransactionCount: Int
    let enteredTransactionCount: Int
    let exitedTransactionCount: Int
    let affectedStatementCount: Int
    let paymentDifferenceStatementCount: Int
}

nonisolated struct StatementRecordRow: Decodable {
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

nonisolated struct StatementPaymentRecordRow: Decodable {
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
    func updateStatementDates(request: UpdateStatementDatesRequest) async throws -> StatementDateUpdateResponse
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

    func updateStatementDates(request: UpdateStatementDatesRequest) async throws -> StatementDateUpdateResponse {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_update_statement_dates", params: request)
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

    func updateDates(statementId: UUID, closingDate: Date, dueDate: Date) async throws -> StatementDateUpdateResult {
        let response = try await remoteStore.updateStatementDates(
            request: UpdateStatementDatesRequest(
                statementId: statementId,
                closingDate: closingDate,
                dueDate: dueDate
            )
        )
        guard response.ok, let statementId = response.statementId else {
            throw StatementRemoteRepositoryError.from(code: response.code)
        }
        return StatementDateUpdateResult(
            statementId: statementId,
            movedTransactionCount: response.movedTransactionCount ?? 0,
            enteredTransactionCount: response.enteredTransactionCount ?? 0,
            exitedTransactionCount: response.exitedTransactionCount ?? 0,
            affectedStatementCount: response.affectedStatementCount ?? 0,
            paymentDifferenceStatementCount: response.paymentDifferenceStatementCount ?? 0
        )
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

    func updateDates(
        statementId: UUID,
        closingDate _: Date,
        dueDate _: Date
    ) async throws -> StatementDateUpdateResult {
        StatementDateUpdateResult(
            statementId: statementId,
            movedTransactionCount: 0,
            enteredTransactionCount: 0,
            exitedTransactionCount: 0,
            affectedStatementCount: 0,
            paymentDifferenceStatementCount: 0
        )
    }
}

struct AuthRequiredStatementRemoteRepository: StatementRemoteRepositoryProtocol {
    func load() async throws -> StatementRemoteSnapshot {
        throw StatementRemoteRepositoryError.authenticationRequired
    }

    func loadTransactions(statementId _: UUID) async throws -> [Transaction] {
        throw StatementRemoteRepositoryError.authenticationRequired
    }

    func updateDates(
        statementId _: UUID,
        closingDate _: Date,
        dueDate _: Date
    ) async throws -> StatementDateUpdateResult {
        throw StatementRemoteRepositoryError.authenticationRequired
    }
}

nonisolated struct ListStatementTransactionsRequest: Encodable {
    let pStatementId: UUID

    init(statementId: UUID) {
        self.pStatementId = statementId
    }

    enum CodingKeys: String, CodingKey {
        case pStatementId = "p_statement_id"
    }
}

nonisolated struct UpdateStatementDatesRequest: Encodable {
    let pStatementId: UUID
    let pClosingDate: String
    let pDueDate: String

    init(statementId: UUID, closingDate: Date, dueDate: Date) {
        self.pStatementId = statementId
        self.pClosingDate = Self.dateOnlyString(from: closingDate)
        self.pDueDate = Self.dateOnlyString(from: dueDate)
    }

    enum CodingKeys: String, CodingKey {
        case pStatementId = "p_statement_id"
        case pClosingDate = "p_closing_date"
        case pDueDate = "p_due_date"
    }

    private static func dateOnlyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

nonisolated struct StatementDateUpdateResponse: Decodable {
    let ok: Bool
    let code: String?
    let statementId: UUID?
    let movedTransactionCount: Int?
    let enteredTransactionCount: Int?
    let exitedTransactionCount: Int?
    let affectedStatementCount: Int?
    let paymentDifferenceStatementCount: Int?

    enum CodingKeys: String, CodingKey {
        case ok
        case code
        case statementId = "statement_id"
        case movedTransactionCount = "moved_transaction_count"
        case enteredTransactionCount = "entered_transaction_count"
        case exitedTransactionCount = "exited_transaction_count"
        case affectedStatementCount = "affected_statement_count"
        case paymentDifferenceStatementCount = "payment_difference_statement_count"
    }
}
