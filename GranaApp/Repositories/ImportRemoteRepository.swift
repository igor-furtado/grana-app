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
    case invalidRefund
    case refundBeforePurchase
    case refundExceedsPurchase
    case unappliedPayment
    case linkedRefundsExist
    case importBatchNotFound
    case unexpectedResponse

    var errorTitle: String {
        switch self {
        case .importBatchNotFound:
            return "Importação não encontrada"
        case .linkedRefundsExist:
            return "Não foi possível desfazer a importação"
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
        case .invalidRefund:
            return "O estorno importado precisa apontar para uma compra válida do mesmo cartão."
        case .refundBeforePurchase:
            return "A data do estorno importado não pode ser anterior à compra original."
        case .refundExceedsPurchase:
            return "Os estornos importados não podem superar o valor da compra original."
        case .unappliedPayment:
            return "O backend não conseguiu reconciliar integralmente os pagamentos das faturas afetadas."
        case .linkedRefundsExist:
            return "Há estornos em outros lançamentos apontando para transações deste lote."
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
        case "import_batch_not_found":
            return .importBatchNotFound
        default:
            return .unexpectedResponse
        }
    }
}

nonisolated struct ImportCommitInput: Hashable, Sendable {
    var idempotencyKey: UUID
    var batches: [ImportBatchCommitInput]
    var rows: [ImportTransactionCommitInput]
    var cacheEntries: [ImportCacheEntryCommitInput]
    var corrections: [ImportCorrectionCommitInput]
}

nonisolated struct ImportBatchCommitInput: Hashable, Sendable {
    var batchId: UUID
    var sourceFilename: String
    var accountId: UUID
    var importedAt: Date
    var importFormat: InstitutionImportFormat
}

nonisolated struct ImportTransactionCommitInput: Hashable, Sendable {
    var transactionId: UUID
    var batchId: UUID
    var categorySlug: String
    var subcategoryId: UUID?
    var amount: Decimal
    var occurredAt: Date
    var description: String
    var notes: String?
    var externalId: String?
    var refundOfTransactionId: UUID?
}

nonisolated struct ImportCacheEntryCommitInput: Hashable, Sendable {
    var descriptionHash: String
    var normalizedDescription: String
    var categorySlug: String
    var subcategoryName: String?
    var confidence: Double
    var model: String
    var createdAt: Date
    var updatedAt: Date

    init(entry: CategorizationPendingCacheEntry) {
        descriptionHash = entry.descriptionHash
        normalizedDescription = entry.normalizedDescription
        categorySlug = entry.categorySlug
        subcategoryName = entry.subcategoryName
        confidence = entry.confidence
        model = entry.model
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
    }
}

nonisolated struct ImportCorrectionCommitInput: Hashable, Sendable {
    var descriptionHash: String
    var normalizedDescription: String
    var originalCategorySlug: String?
    var originalSubcategoryName: String?
    var correctedCategorySlug: String
    var correctedSubcategoryName: String?
    var transactionId: UUID
    var createdAt: Date

    init(correction: CategorizationPendingCorrection) {
        descriptionHash = correction.descriptionHash
        normalizedDescription = correction.normalizedDescription
        originalCategorySlug = correction.originalCategorySlug
        originalSubcategoryName = correction.originalSubcategoryName
        correctedCategorySlug = correction.correctedCategorySlug
        correctedSubcategoryName = correction.correctedSubcategoryName
        transactionId = correction.transactionId
        createdAt = correction.createdAt
    }
}

nonisolated struct ImportCommitDuplicateRow: Decodable, Equatable, Sendable {
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

nonisolated struct ImportCommitResult: Decodable, Equatable, Sendable {
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

nonisolated struct ImportBatchRecordRow: Decodable, Sendable {
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

nonisolated struct ImportMutationResponse: Decodable, Sendable {
    let ok: Bool
    let code: String?
}

nonisolated struct ImportCommitResponse: Decodable, Sendable {
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
        ok = try container.decode(Bool.self, forKey: .ok)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        importedBatchIds = try container.decodeIfPresent([UUID].self, forKey: .importedBatchIds) ?? []
        importedRowCount = try container.decodeIfPresent(Int.self, forKey: .importedRowCount) ?? 0
        duplicateRows = try container.decodeIfPresent([ImportCommitDuplicateRow].self, forKey: .duplicateRows) ?? []
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

nonisolated struct CommitImportRequest: Encodable, Sendable {
    let pIdempotencyKey: UUID
    let pBatches: [CommitImportBatchRequest]
    let pTransactions: [CommitImportTransactionRequest]
    let pCacheEntries: [CommitImportCacheEntryRequest]
    let pCorrections: [CommitImportCorrectionRequest]

    init(input: ImportCommitInput) {
        pIdempotencyKey = input.idempotencyKey
        pBatches = input.batches.map(CommitImportBatchRequest.init)
        pTransactions = input.rows.map(CommitImportTransactionRequest.init)
        pCacheEntries = input.cacheEntries.map(CommitImportCacheEntryRequest.init)
        pCorrections = input.corrections.map(CommitImportCorrectionRequest.init)
    }

    enum CodingKeys: String, CodingKey {
        case pIdempotencyKey = "p_idempotency_key"
        case pBatches = "p_batches"
        case pTransactions = "p_transactions"
        case pCacheEntries = "p_cache_entries"
        case pCorrections = "p_corrections"
    }
}

nonisolated struct CommitImportBatchRequest: Encodable, Hashable, Sendable {
    let batchId: UUID
    let sourceFilename: String
    let accountId: UUID
    let importedAt: Date
    let importFormat: String

    init(input: ImportBatchCommitInput) {
        batchId = input.batchId
        sourceFilename = input.sourceFilename
        accountId = input.accountId
        importedAt = input.importedAt
        importFormat = input.importFormat.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case sourceFilename = "source_filename"
        case accountId = "account_id"
        case importedAt = "imported_at"
        case importFormat = "import_format"
    }
}

nonisolated struct CommitImportTransactionRequest: Encodable, Hashable, Sendable {
    let transactionId: UUID
    let batchId: UUID
    let categorySlug: String
    let subcategoryId: UUID?
    let amountCents: Int64
    let occurredAt: Date
    let description: String
    let notes: String?
    let externalId: String?
    let refundOfTransactionId: UUID?

    init(input: ImportTransactionCommitInput) {
        transactionId = input.transactionId
        batchId = input.batchId
        categorySlug = input.categorySlug
        subcategoryId = input.subcategoryId
        amountCents = Converters.decimalToCents(input.amount)
        occurredAt = input.occurredAt
        description = input.description
        notes = input.notes
        externalId = input.externalId
        refundOfTransactionId = input.refundOfTransactionId
    }

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case batchId = "batch_id"
        case categorySlug = "category_slug"
        case subcategoryId = "subcategory_id"
        case amountCents = "amount_cents"
        case occurredAt = "occurred_at"
        case description
        case notes
        case externalId = "external_id"
        case refundOfTransactionId = "refund_of_transaction_id"
    }
}

nonisolated struct CommitImportCacheEntryRequest: Encodable, Hashable, Sendable {
    let descriptionHash: String
    let normalizedDescription: String
    let categorySlug: String
    let subcategoryName: String?
    let confidence: Double
    let model: String
    let createdAt: Date
    let updatedAt: Date

    init(input: ImportCacheEntryCommitInput) {
        descriptionHash = input.descriptionHash
        normalizedDescription = input.normalizedDescription
        categorySlug = input.categorySlug
        subcategoryName = input.subcategoryName
        confidence = input.confidence
        model = input.model
        createdAt = input.createdAt
        updatedAt = input.updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case descriptionHash = "description_hash"
        case normalizedDescription = "normalized_description"
        case categorySlug = "category_slug"
        case subcategoryName = "subcategory_name"
        case confidence
        case model
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct CommitImportCorrectionRequest: Encodable, Hashable, Sendable {
    let descriptionHash: String
    let normalizedDescription: String
    let originalCategorySlug: String?
    let originalSubcategoryName: String?
    let correctedCategorySlug: String
    let correctedSubcategoryName: String?
    let transactionId: UUID
    let createdAt: Date

    init(input: ImportCorrectionCommitInput) {
        descriptionHash = input.descriptionHash
        normalizedDescription = input.normalizedDescription
        originalCategorySlug = input.originalCategorySlug
        originalSubcategoryName = input.originalSubcategoryName
        correctedCategorySlug = input.correctedCategorySlug
        correctedSubcategoryName = input.correctedSubcategoryName
        transactionId = input.transactionId
        createdAt = input.createdAt
    }

    enum CodingKeys: String, CodingKey {
        case descriptionHash = "description_hash"
        case normalizedDescription = "normalized_description"
        case originalCategorySlug = "original_category_slug"
        case originalSubcategoryName = "original_subcategory_name"
        case correctedCategorySlug = "corrected_category_slug"
        case correctedSubcategoryName = "corrected_subcategory_name"
        case transactionId = "transaction_id"
        case createdAt = "created_at"
    }
}

nonisolated struct DeleteImportBatchRequest: Encodable, Sendable {
    let pBatchId: UUID

    init(batchId: UUID) {
        pBatchId = batchId
    }

    enum CodingKeys: String, CodingKey {
        case pBatchId = "p_batch_id"
    }
}
