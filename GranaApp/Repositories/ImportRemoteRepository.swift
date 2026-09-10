import Foundation
import Supabase

protocol ImportRemoteRepositoryProtocol: Sendable {
    func loadBatches() async throws -> [ImportBatch]
    func commit(input: ImportCommitInput) async throws -> ImportCommitResult
    func delete(batchId: UUID) async throws
}

nonisolated enum ImportRemoteRepositoryError: UserFacingError, Equatable {
    case authenticationRequired
    case invalidAccount
    case invalidCategory
    case invalidSubcategory
    case unsupportedImportFormat
    case unappliedPayment
    case importBatchNotFound
    case unexpectedResponse

    var errorTitle: String {
        switch self {
        case .importBatchNotFound:
            return "Importação não encontrada"
        default:
            return "Falha ao concluir importação"
        }
    }

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "É preciso entrar com sua conta para importar e desfazer lotes."
        case .invalidAccount:
            return "A conta selecionada para o lote não está disponível."
        case .invalidCategory:
            return "A categoria selecionada não existe no catálogo global."
        case .invalidSubcategory:
            return "A subcategoria selecionada não pertence à categoria informada."
        case .unsupportedImportFormat:
            return "A conta selecionada não suporta esse formato de importação."
        case .unappliedPayment:
            return "O backend não conseguiu reconciliar integralmente os pagamentos das faturas afetadas."
        case .importBatchNotFound:
            return "O lote selecionado não foi encontrado para desfazer a importação."
        case .unexpectedResponse:
            return "A resposta do backend para importação veio inválida."
        }
    }

    static func from(code: String?) -> ImportRemoteRepositoryError {
        switch code {
        case "invalid_account":
            return .invalidAccount
        case "invalid_category":
            return .invalidCategory
        case "invalid_subcategory":
            return .invalidSubcategory
        case "unsupported_import_format":
            return .unsupportedImportFormat
        case "unapplied_payment":
            return .unappliedPayment
        case "import_batch_not_found":
            return .importBatchNotFound
        default:
            return .unexpectedResponse
        }
    }
}

nonisolated struct ImportCommitInput: Hashable {
    var idempotencyKey: UUID
    var batches: [ImportBatchCommitInput]
    var rows: [ImportTransactionCommitInput]
}

nonisolated struct ImportBatchCommitInput: Hashable {
    var batchId: UUID
    var sourceFilename: String
    var accountId: UUID
    var importedAt: Date
    var importFormat: InstitutionImportFormat
}

nonisolated struct ImportTransactionCommitInput: Hashable {
    var transactionId: UUID
    var batchId: UUID
    var accountId: UUID
    var categorySlug: String
    var subcategoryId: UUID?
    var destinationAccountId: UUID?
    var amount: Decimal
    var occurredAt: Date
    var originOccurredAt: Date
    var purchaseType: TransactionPurchaseType?
    var installmentIndex: Int?
    var installmentCount: Int?
    var description: String
    var notes: String?
    var externalId: String?
}

nonisolated struct ImportCommitDuplicateRow: Decodable, Equatable {
    let batchId: UUID
    let externalId: String
    let description: String
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case externalId = "external_id"
        case description
        case occurredAt = "occurred_at"
    }
}

nonisolated struct ImportCommitResult: Decodable, Equatable {
    let batchIds: [UUID]
    let importedRowCount: Int
    let duplicateRows: [ImportCommitDuplicateRow]

    var duplicateCount: Int {
        duplicateRows.count
    }

    enum CodingKeys: String, CodingKey {
        case batchIds = "imported_batch_ids"
        case importedRowCount = "imported_row_count"
        case duplicateRows = "duplicate_rows"
    }
}

nonisolated struct ImportBatchRecordRow: Decodable {
    let id: UUID
    let sourceFilename: String
    let accountId: UUID
    let rowCount: Int
    let importedAt: Date
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sourceFilename = "source_filename"
        case accountId = "account_id"
        case rowCount = "row_count"
        case importedAt = "imported_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct ImportMutationResponse: Decodable {
    let ok: Bool
    let code: String?
}

nonisolated struct ImportCommitResponse: Decodable {
    let ok: Bool
    let code: String?
    let importedBatchIds: [UUID]
    let importedRowCount: Int
    let duplicateRows: [ImportCommitDuplicateRow]

    enum CodingKeys: String, CodingKey {
        case ok
        case code
        case importedBatchIds = "imported_batch_ids"
        case importedRowCount = "imported_row_count"
        case duplicateRows = "duplicate_rows"
    }

    init(
        ok: Bool,
        code: String?,
        importedBatchIds: [UUID],
        importedRowCount: Int,
        duplicateRows: [ImportCommitDuplicateRow]
    ) {
        self.ok = ok
        self.code = code
        self.importedBatchIds = importedBatchIds
        self.importedRowCount = importedRowCount
        self.duplicateRows = duplicateRows
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.code = try container.decodeIfPresent(String.self, forKey: .code)
        self.importedBatchIds = try container.decodeIfPresent([UUID].self, forKey: .importedBatchIds) ?? []
        self.importedRowCount = try container.decodeIfPresent(Int.self, forKey: .importedRowCount) ?? 0
        self.duplicateRows = try container
            .decodeIfPresent([ImportCommitDuplicateRow].self, forKey: .duplicateRows) ?? []
    }
}

protocol ImportRemoteStore: Sendable {
    func fetchBatches() async throws -> [ImportBatchRecordRow]
    func commitImport(request: CommitImportRequest) async throws -> ImportCommitResponse
    func deleteImportBatch(request: DeleteImportBatchRequest) async throws -> ImportMutationResponse
}

actor SupabaseImportRemoteStore: ImportRemoteStore {
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

    func fetchBatches() async throws -> [ImportBatchRecordRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_list_import_batches")
            .execute()
            .value
    }

    func commitImport(request: CommitImportRequest) async throws -> ImportCommitResponse {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_commit_import", params: request)
            .execute()
            .value
    }

    func deleteImportBatch(request: DeleteImportBatchRequest) async throws -> ImportMutationResponse {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_delete_import_batch", params: request)
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

final class ImportRemoteRepository: ImportRemoteRepositoryProtocol, Sendable {
    private let remoteStore: any ImportRemoteStore

    init(remoteStore: any ImportRemoteStore) {
        self.remoteStore = remoteStore
    }

    func loadBatches() async throws -> [ImportBatch] {
        try await remoteStore.fetchBatches().map(Self.mapBatch)
    }

    func commit(input: ImportCommitInput) async throws -> ImportCommitResult {
        let response = try await remoteStore.commitImport(
            request: CommitImportRequest(input: input)
        )
        guard response.ok else {
            throw ImportRemoteRepositoryError.from(code: response.code)
        }
        return ImportCommitResult(
            batchIds: response.importedBatchIds,
            importedRowCount: response.importedRowCount,
            duplicateRows: response.duplicateRows
        )
    }

    func delete(batchId: UUID) async throws {
        let response = try await remoteStore.deleteImportBatch(
            request: DeleteImportBatchRequest(batchId: batchId)
        )
        guard response.ok else {
            throw ImportRemoteRepositoryError.from(code: response.code)
        }
    }

    private static func mapBatch(_ row: ImportBatchRecordRow) -> ImportBatch {
        ImportBatch(
            id: row.id,
            sourceFilename: row.sourceFilename,
            accountId: row.accountId,
            rowCount: row.rowCount,
            importedAt: row.importedAt,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }
}

struct StaticImportRemoteRepository: ImportRemoteRepositoryProtocol {
    let batches: [ImportBatch]
    var commitResult: ImportCommitResult = .init(
        batchIds: [],
        importedRowCount: 0,
        duplicateRows: []
    )

    func loadBatches() async throws -> [ImportBatch] {
        batches
    }

    func commit(input _: ImportCommitInput) async throws -> ImportCommitResult {
        commitResult
    }

    func delete(batchId _: UUID) async throws {}
}

struct AuthRequiredImportRemoteRepository: ImportRemoteRepositoryProtocol {
    func loadBatches() async throws -> [ImportBatch] {
        throw ImportRemoteRepositoryError.authenticationRequired
    }

    func commit(input _: ImportCommitInput) async throws -> ImportCommitResult {
        throw ImportRemoteRepositoryError.authenticationRequired
    }

    func delete(batchId _: UUID) async throws {
        throw ImportRemoteRepositoryError.authenticationRequired
    }
}

nonisolated struct CommitImportRequest: Encodable {
    let pIdempotencyKey: UUID
    let pBatches: [CommitImportBatchRequest]
    let pTransactions: [CommitImportTransactionRequest]

    init(input: ImportCommitInput) {
        self.pIdempotencyKey = input.idempotencyKey
        self.pBatches = input.batches.map(CommitImportBatchRequest.init)
        self.pTransactions = input.rows.map(CommitImportTransactionRequest.init)
    }

    enum CodingKeys: String, CodingKey {
        case pIdempotencyKey = "p_idempotency_key"
        case pBatches = "p_batches"
        case pTransactions = "p_transactions"
    }
}

nonisolated struct CommitImportBatchRequest: Encodable, Hashable {
    let batchId: UUID
    let sourceFilename: String
    let accountId: UUID
    let importedAt: Date
    let importFormat: String

    init(input: ImportBatchCommitInput) {
        self.batchId = input.batchId
        self.sourceFilename = input.sourceFilename
        self.accountId = input.accountId
        self.importedAt = input.importedAt
        self.importFormat = input.importFormat.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case sourceFilename = "source_filename"
        case accountId = "account_id"
        case importedAt = "imported_at"
        case importFormat = "import_format"
    }
}

nonisolated struct CommitImportTransactionRequest: Encodable, Hashable {
    let transactionId: UUID
    let batchId: UUID
    let accountId: UUID
    let categorySlug: String
    let subcategoryId: UUID?
    let destinationAccountId: UUID?
    let amountCents: Int64
    let occurredAt: Date
    let originOccurredAt: Date
    let purchaseType: String?
    let installmentIndex: Int?
    let installmentCount: Int?
    let description: String
    let notes: String?
    let externalId: String?

    init(input: ImportTransactionCommitInput) {
        self.transactionId = input.transactionId
        self.batchId = input.batchId
        self.accountId = input.accountId
        self.categorySlug = input.categorySlug
        self.subcategoryId = input.subcategoryId
        self.destinationAccountId = input.destinationAccountId
        self.amountCents = Converters.decimalToCents(input.amount)
        self.occurredAt = input.occurredAt
        self.originOccurredAt = input.originOccurredAt
        self.purchaseType = input.purchaseType?.rawValue
        self.installmentIndex = input.installmentIndex
        self.installmentCount = input.installmentCount
        self.description = input.description
        self.notes = input.notes
        self.externalId = input.externalId
    }

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case batchId = "batch_id"
        case accountId = "account_id"
        case categorySlug = "category_slug"
        case subcategoryId = "subcategory_id"
        case destinationAccountId = "destination_account_id"
        case amountCents = "amount_cents"
        case occurredAt = "occurred_at"
        case originOccurredAt = "origin_occurred_at"
        case purchaseType = "purchase_type"
        case installmentIndex = "installment_index"
        case installmentCount = "installment_count"
        case description
        case notes
        case externalId = "external_id"
    }
}

nonisolated struct DeleteImportBatchRequest: Encodable {
    let pBatchId: UUID

    init(batchId: UUID) {
        self.pBatchId = batchId
    }

    enum CodingKeys: String, CodingKey {
        case pBatchId = "p_batch_id"
    }
}
