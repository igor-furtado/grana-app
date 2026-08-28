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

nonisolated struct TransactionRemotePageCursor: Codable, Hashable {
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

extension TransactionRemoteRepositoryProtocol {
    func loadAll(pageSize: Int = 200) async throws -> [Transaction] {
        var cursor: TransactionRemotePageCursor?
        var all: [Transaction] = []

        repeat {
            let page = try await loadPage(cursor: cursor, limit: pageSize)
            all.append(contentsOf: page.transactions)
            cursor = page.nextCursor
        } while cursor != nil

        return all
    }

    func externalIds(forAccount accountId: UUID, pageSize: Int = 200) async throws -> Set<String> {
        try Set(
            await loadAll(pageSize: pageSize)
                .lazy
                .filter { $0.accountId == accountId }
                .compactMap(\.externalId)
        )
    }
}

nonisolated enum TransactionRemoteRepositoryError: UserFacingError, Equatable {
    case authenticationRequired
    case invalidAmount
    case invalidAccount
    case invalidCategory
    case invalidSubcategory
    case invalidTransferDestination
    case invalidRefund
    case refundBeforePurchase
    case refundExceedsPurchase
    case unappliedPayment
    case linkedRefundsExist
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
        case .invalidRefund:
            return "O estorno precisa apontar para uma compra válida do mesmo cartão."
        case .refundBeforePurchase:
            return "A data do estorno não pode ser anterior à compra original."
        case .refundExceedsPurchase:
            return "A soma dos estornos não pode superar o valor da compra original."
        case .unappliedPayment:
            return "O pagamento precisa ser integralmente aplicado às faturas elegíveis nessa data."
        case .linkedRefundsExist:
            return "Não é possível apagar uma transação enquanto houver estornos vinculados."
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
        case "invalid_refund":
            return .invalidRefund
        case "refund_before_purchase":
            return .refundBeforePurchase
        case "refund_exceeds_purchase":
            return .refundExceedsPurchase
        case "unapplied_payment":
            return .unappliedPayment
        case "linked_refunds_exist":
            return .linkedRefundsExist
        case "transaction_not_found":
            return .transactionNotFound
        default:
            return .unexpectedResponse
        }
    }
}

nonisolated struct TransactionMutationInput: Hashable {
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

nonisolated struct TransactionRecordRow: Decodable {
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

nonisolated struct TransactionMutationResponse: Decodable {
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

    static func mapTransaction(_ row: TransactionRecordRow) -> Transaction {
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

nonisolated struct ListTransactionsRequest: Encodable {
    let pLimit: Int
    let pAfterOccurredAt: Date?
    let pAfterCreatedAt: Date?
    let pAfterId: UUID?

    init(cursor: TransactionRemotePageCursor?, limit: Int) {
        self.pLimit = limit
        self.pAfterOccurredAt = cursor?.occurredAt
        self.pAfterCreatedAt = cursor?.createdAt
        self.pAfterId = cursor?.id
    }

    enum CodingKeys: String, CodingKey {
        case pLimit = "p_limit"
        case pAfterOccurredAt = "p_after_occurred_at"
        case pAfterCreatedAt = "p_after_created_at"
        case pAfterId = "p_after_id"
    }
}

nonisolated struct CreateTransactionRequest: Encodable {
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
        self.pAccountId = input.accountId
        self.pCategoryId = input.categoryId
        self.pSubcategoryId = input.subcategoryId
        self.pAmountCents = Converters.decimalToCents(input.amount)
        self.pOccurredAt = input.occurredAt
        self.pDescription = input.description
        self.pNotes = input.notes
        self.pDestinationAccountId = input.destinationAccountId
        self.pRefundOfTransactionId = input.refundOfTransactionId
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

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pAccountId, forKey: .pAccountId)
        try container.encode(pCategoryId, forKey: .pCategoryId)
        try container.encode(pSubcategoryId, forKey: .pSubcategoryId)
        try container.encode(pAmountCents, forKey: .pAmountCents)
        try container.encode(pOccurredAt, forKey: .pOccurredAt)
        try container.encode(pDescription, forKey: .pDescription)
        try container.encode(pNotes, forKey: .pNotes)
        try container.encode(pDestinationAccountId, forKey: .pDestinationAccountId)
        try container.encode(pRefundOfTransactionId, forKey: .pRefundOfTransactionId)
    }
}

nonisolated struct UpdateTransactionRequest: Encodable {
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
        self.pTransactionId = transactionId
        self.pAccountId = input.accountId
        self.pCategoryId = input.categoryId
        self.pSubcategoryId = input.subcategoryId
        self.pAmountCents = Converters.decimalToCents(input.amount)
        self.pOccurredAt = input.occurredAt
        self.pDescription = input.description
        self.pNotes = input.notes
        self.pDestinationAccountId = input.destinationAccountId
        self.pRefundOfTransactionId = input.refundOfTransactionId
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

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pTransactionId, forKey: .pTransactionId)
        try container.encode(pAccountId, forKey: .pAccountId)
        try container.encode(pCategoryId, forKey: .pCategoryId)
        try container.encode(pSubcategoryId, forKey: .pSubcategoryId)
        try container.encode(pAmountCents, forKey: .pAmountCents)
        try container.encode(pOccurredAt, forKey: .pOccurredAt)
        try container.encode(pDescription, forKey: .pDescription)
        try container.encode(pNotes, forKey: .pNotes)
        try container.encode(pDestinationAccountId, forKey: .pDestinationAccountId)
        try container.encode(pRefundOfTransactionId, forKey: .pRefundOfTransactionId)
    }
}

nonisolated struct DeleteTransactionRequest: Encodable {
    let pTransactionId: UUID

    init(transactionId: UUID) {
        self.pTransactionId = transactionId
    }

    enum CodingKeys: String, CodingKey {
        case pTransactionId = "p_transaction_id"
    }
}
