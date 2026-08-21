import Foundation
import Supabase

nonisolated struct TransactionRemotePage: @unchecked Sendable {
    var transactions: [Transaction]
    var nextCursor: TransactionRemotePageCursor?

    static let empty = TransactionRemotePage(
        transactions: [],
        nextCursor: nil
    )
}

nonisolated struct TransactionRemotePageCursor: Codable, Hashable, Sendable {
    let occurredAt: Date
    let createdAt: Date
    let id: UUID
}

protocol TransactionRemoteRepositoryProtocol: Sendable {
    func loadPage(cursor: TransactionRemotePageCursor?, limit: Int) async throws -> TransactionRemotePage
    func create(input: TransactionMutationInput) async throws
    func update(transactionId: UUID, input: TransactionMutationInput) async throws
    func delete(transactionId: UUID) async throws
}

nonisolated enum TransactionRemoteRepositoryError: UserFacingError, Equatable {
    case authenticationRequired
    case invalidAmount
    case invalidAccount
    case invalidCategory
    case invalidSubcategory
    case invalidTransferDestination
    case refundsNotSupported
    case linkedRefundsExist
    case creditCardTransactionsNotSupported
    case transactionNotFound
    case unexpectedResponse

    var errorTitle: String {
        switch self {
        case .transactionNotFound:
            return "Transação não encontrada"
        default:
            return "Falha ao salvar transação"
        }
    }

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "É preciso entrar com sua conta para carregar e salvar transações."
        case .invalidAmount:
            return "Informe um valor maior que zero para salvar a transação."
        case .invalidAccount:
            return "A conta selecionada não está disponível para esta transação."
        case .invalidCategory:
            return "A categoria selecionada não está disponível no catálogo global."
        case .invalidSubcategory:
            return "A subcategoria selecionada não pertence à categoria informada."
        case .invalidTransferDestination:
            return "Escolha uma conta de destino diferente da conta de origem."
        case .refundsNotSupported:
            return "Estornos de cartão serão migrados junto com a fatia de faturas."
        case .linkedRefundsExist:
            return "Não é possível apagar uma transação enquanto houver estornos vinculados."
        case .creditCardTransactionsNotSupported:
            return "Transações de cartão serão migradas junto com a fatia de faturas."
        case .transactionNotFound:
            return "A transação não foi encontrada para concluir a operação."
        case .unexpectedResponse:
            return "A resposta do backend para transações veio inválida."
        }
    }

    static func from(code: String?) -> TransactionRemoteRepositoryError {
        switch code {
        case "invalid_amount":
            return .invalidAmount
        case "invalid_account":
            return .invalidAccount
        case "invalid_category":
            return .invalidCategory
        case "invalid_subcategory":
            return .invalidSubcategory
        case "invalid_transfer_destination":
            return .invalidTransferDestination
        case "refunds_not_supported":
            return .refundsNotSupported
        case "linked_refunds_exist":
            return .linkedRefundsExist
        case "credit_card_transactions_not_supported":
            return .creditCardTransactionsNotSupported
        case "transaction_not_found":
            return .transactionNotFound
        default:
            return .unexpectedResponse
        }
    }
}

nonisolated struct TransactionMutationInput: Hashable, Sendable {
    var accountId: UUID
    var categoryId: UUID
    var subcategoryId: UUID?
    var amount: Decimal
    var occurredAt: Date
    var description: String
    var notes: String?
    var destinationAccountId: UUID?
    var refundOfTransactionId: UUID?
}

nonisolated struct TransactionRecordRow: Decodable, Sendable {
    let id: UUID
    let accountId: UUID
    let categoryId: UUID
    let subcategoryId: UUID?
    let amountCents: Int64
    let occurredAt: Date
    let description: String
    let notes: String?
    let importBatchId: UUID?
    let externalId: String?
    let destinationAccountId: UUID?
    let statementId: UUID?
    let refundOfTransactionId: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case categoryId = "category_id"
        case subcategoryId = "subcategory_id"
        case amountCents = "amount_cents"
        case occurredAt = "occurred_at"
        case description
        case notes
        case importBatchId = "import_batch_id"
        case externalId = "external_id"
        case destinationAccountId = "destination_account_id"
        case statementId = "statement_id"
        case refundOfTransactionId = "refund_of_transaction_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct TransactionMutationResponse: Decodable, Sendable {
    let ok: Bool
    let code: String?
    let transactionId: UUID?

    enum CodingKeys: String, CodingKey {
        case ok
        case code
        case transactionId = "transaction_id"
    }
}

protocol TransactionRemoteStore: Sendable {
    func fetchTransactions(request: ListTransactionsRequest) async throws -> [TransactionRecordRow]
    func createTransaction(request: CreateTransactionRequest) async throws -> TransactionMutationResponse
    func updateTransaction(request: UpdateTransactionRequest) async throws -> TransactionMutationResponse
    func deleteTransaction(request: DeleteTransactionRequest) async throws -> TransactionMutationResponse
}

actor SupabaseTransactionRemoteStore: TransactionRemoteStore {
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

    func fetchTransactions(request: ListTransactionsRequest) async throws -> [TransactionRecordRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_list_transactions", params: request)
            .execute()
            .value
    }

    func createTransaction(request: CreateTransactionRequest) async throws -> TransactionMutationResponse {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_create_transaction", params: request)
            .execute()
            .value
    }

    func updateTransaction(request: UpdateTransactionRequest) async throws -> TransactionMutationResponse {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_update_transaction", params: request)
            .execute()
            .value
    }

    func deleteTransaction(request: DeleteTransactionRequest) async throws -> TransactionMutationResponse {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_delete_transaction", params: request)
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

final class TransactionRemoteRepository: TransactionRemoteRepositoryProtocol, Sendable {
    private let remoteStore: any TransactionRemoteStore

    init(remoteStore: any TransactionRemoteStore) {
        self.remoteStore = remoteStore
    }

    func loadPage(
        cursor: TransactionRemotePageCursor?,
        limit: Int
    ) async throws -> TransactionRemotePage {
        let normalizedLimit = max(1, limit)
        let rows = try await remoteStore.fetchTransactions(
            request: ListTransactionsRequest(cursor: cursor, limit: normalizedLimit + 1)
        )
        let pageRows = Array(rows.prefix(normalizedLimit))
        let transactions = pageRows.map(Self.mapTransaction)
        let hasMore = rows.count > normalizedLimit
        let nextCursor = hasMore ? pageRows.last.map {
            TransactionRemotePageCursor(
                occurredAt: $0.occurredAt,
                createdAt: $0.createdAt,
                id: $0.id
            )
        } : nil
        return TransactionRemotePage(
            transactions: transactions,
            nextCursor: nextCursor
        )
    }

    func create(input: TransactionMutationInput) async throws {
        let response = try await remoteStore.createTransaction(
            request: CreateTransactionRequest(input: input)
        )
        try validate(response)
    }

    func update(transactionId: UUID, input: TransactionMutationInput) async throws {
        let response = try await remoteStore.updateTransaction(
            request: UpdateTransactionRequest(transactionId: transactionId, input: input)
        )
        try validate(response)
    }

    func delete(transactionId: UUID) async throws {
        let response = try await remoteStore.deleteTransaction(
            request: DeleteTransactionRequest(transactionId: transactionId)
        )
        try validate(response)
    }

    private func validate(_ response: TransactionMutationResponse) throws {
        guard response.ok else {
            throw TransactionRemoteRepositoryError.from(code: response.code)
        }
    }

    private static func mapTransaction(_ row: TransactionRecordRow) -> Transaction {
        Transaction(
            id: row.id,
            accountId: row.accountId,
            categoryId: row.categoryId,
            subcategoryId: row.subcategoryId,
            amount: Converters.centsToDecimal(row.amountCents),
            occurredAt: row.occurredAt,
            description: row.description,
            notes: row.notes,
            importBatchId: row.importBatchId,
            externalId: row.externalId,
            destinationAccountId: row.destinationAccountId,
            statementId: row.statementId,
            refundOfTransactionId: row.refundOfTransactionId,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }
}

struct StaticTransactionRemoteRepository: TransactionRemoteRepositoryProtocol {
    let page: TransactionRemotePage

    func loadPage(
        cursor _: TransactionRemotePageCursor?,
        limit _: Int
    ) async throws -> TransactionRemotePage {
        page
    }

    func create(input _: TransactionMutationInput) async throws {}

    func update(transactionId _: UUID, input _: TransactionMutationInput) async throws {}

    func delete(transactionId _: UUID) async throws {}
}

struct AuthRequiredTransactionRemoteRepository: TransactionRemoteRepositoryProtocol {
    func loadPage(
        cursor _: TransactionRemotePageCursor?,
        limit _: Int
    ) async throws -> TransactionRemotePage {
        throw TransactionRemoteRepositoryError.authenticationRequired
    }

    func create(input _: TransactionMutationInput) async throws {
        throw TransactionRemoteRepositoryError.authenticationRequired
    }

    func update(transactionId _: UUID, input _: TransactionMutationInput) async throws {
        throw TransactionRemoteRepositoryError.authenticationRequired
    }

    func delete(transactionId _: UUID) async throws {
        throw TransactionRemoteRepositoryError.authenticationRequired
    }
}

nonisolated struct ListTransactionsRequest: Encodable, Sendable {
    let pLimit: Int
    let pAfterOccurredAt: Date?
    let pAfterCreatedAt: Date?
    let pAfterId: UUID?

    init(cursor: TransactionRemotePageCursor?, limit: Int) {
        pLimit = limit
        pAfterOccurredAt = cursor?.occurredAt
        pAfterCreatedAt = cursor?.createdAt
        pAfterId = cursor?.id
    }

    enum CodingKeys: String, CodingKey {
        case pLimit = "p_limit"
        case pAfterOccurredAt = "p_after_occurred_at"
        case pAfterCreatedAt = "p_after_created_at"
        case pAfterId = "p_after_id"
    }
}

nonisolated struct CreateTransactionRequest: Encodable, Sendable {
    let pAccountId: UUID
    let pCategoryId: UUID
    let pSubcategoryId: UUID?
    let pAmountCents: Int64
    let pOccurredAt: Date
    let pDescription: String
    let pNotes: String?
    let pDestinationAccountId: UUID?
    let pRefundOfTransactionId: UUID?

    init(input: TransactionMutationInput) {
        pAccountId = input.accountId
        pCategoryId = input.categoryId
        pSubcategoryId = input.subcategoryId
        pAmountCents = Converters.decimalToCents(input.amount)
        pOccurredAt = input.occurredAt
        pDescription = input.description
        pNotes = input.notes
        pDestinationAccountId = input.destinationAccountId
        pRefundOfTransactionId = input.refundOfTransactionId
    }

    enum CodingKeys: String, CodingKey {
        case pAccountId = "p_account_id"
        case pCategoryId = "p_category_id"
        case pSubcategoryId = "p_subcategory_id"
        case pAmountCents = "p_amount_cents"
        case pOccurredAt = "p_occurred_at"
        case pDescription = "p_description"
        case pNotes = "p_notes"
        case pDestinationAccountId = "p_destination_account_id"
        case pRefundOfTransactionId = "p_refund_of_transaction_id"
    }
}

nonisolated struct UpdateTransactionRequest: Encodable, Sendable {
    let pTransactionId: UUID
    let pAccountId: UUID
    let pCategoryId: UUID
    let pSubcategoryId: UUID?
    let pAmountCents: Int64
    let pOccurredAt: Date
    let pDescription: String
    let pNotes: String?
    let pDestinationAccountId: UUID?
    let pRefundOfTransactionId: UUID?

    init(transactionId: UUID, input: TransactionMutationInput) {
        pTransactionId = transactionId
        pAccountId = input.accountId
        pCategoryId = input.categoryId
        pSubcategoryId = input.subcategoryId
        pAmountCents = Converters.decimalToCents(input.amount)
        pOccurredAt = input.occurredAt
        pDescription = input.description
        pNotes = input.notes
        pDestinationAccountId = input.destinationAccountId
        pRefundOfTransactionId = input.refundOfTransactionId
    }

    enum CodingKeys: String, CodingKey {
        case pTransactionId = "p_transaction_id"
        case pAccountId = "p_account_id"
        case pCategoryId = "p_category_id"
        case pSubcategoryId = "p_subcategory_id"
        case pAmountCents = "p_amount_cents"
        case pOccurredAt = "p_occurred_at"
        case pDescription = "p_description"
        case pNotes = "p_notes"
        case pDestinationAccountId = "p_destination_account_id"
        case pRefundOfTransactionId = "p_refund_of_transaction_id"
    }
}

nonisolated struct DeleteTransactionRequest: Encodable, Sendable {
    let pTransactionId: UUID

    init(transactionId: UUID) {
        pTransactionId = transactionId
    }

    enum CodingKeys: String, CodingKey {
        case pTransactionId = "p_transaction_id"
    }
}
