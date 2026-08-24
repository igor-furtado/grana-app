import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("ImportRemoteRepository")
struct ImportRemoteRepositoryTests {
    @Test("Mapeia relatório de duplicatas retornado pelo backend")
    func mapsDuplicateImportReport() async throws {
        let batchId = UUID()
        let occurredAt = Date()
        let repository = ImportRemoteRepository(
            remoteStore: FakeImportRemoteStore(
                commitResponse: ImportCommitResponse(
                    ok: true,
                    code: nil,
                    importedBatchIds: [batchId],
                    importedRowCount: 2,
                    duplicateRows: [
                        ImportCommitDuplicateRow(
                            batchId: batchId,
                            externalId: "FIT-1",
                            description: "Pix recebido",
                            occurredAt: occurredAt
                        ),
                    ]
                )
            )
        )

        let result = try await repository.commit(
            input: ImportCommitInput(
                idempotencyKey: UUID(),
                batches: [],
                rows: [],
                cacheEntries: [],
                corrections: []
            )
        )

        #expect(result.batchIds == [batchId])
        #expect(result.importedRowCount == 2)
        #expect(result.duplicateCount == 1)
        #expect(result.duplicateRows.first?.externalId == "FIT-1")
    }

    @Test("Mapeia erro estável de conta inválida")
    func mapsStableInvalidAccountCode() async {
        let repository = ImportRemoteRepository(
            remoteStore: FakeImportRemoteStore(
                commitResponse: ImportCommitResponse(
                    ok: false,
                    code: "invalid_account",
                    importedBatchIds: [],
                    importedRowCount: 0,
                    duplicateRows: []
                )
            )
        )

        await #expect(throws: ImportRemoteRepositoryError.invalidAccount) {
            try await repository.commit(
                input: ImportCommitInput(
                    idempotencyKey: UUID(),
                    batches: [],
                    rows: [],
                    cacheEntries: [],
                    corrections: []
                )
            )
        }
    }
}

@MainActor
@Suite("ImportStore remote commit")
struct ImportStoreRemoteCommitTests {
    @Test("Monta payload com slugs e propaga idempotency key até a request RPC")
    func buildsStructuredPayloadAndPassesIdempotencyKey() throws {
        let batchId = UUID()
        let transactionId = UUID()
        let rootCategoryId = UUID()
        let subcategoryId = UUID()
        let fallbackId = UUID()
        let key = UUID()
        let occurredAt = Date()
        let categories = [
            makeCategory(
                id: fallbackId,
                slug: "nao-classificado",
                name: "Não Classificado",
                kind: .expense
            ),
            makeCategory(
                id: rootCategoryId,
                slug: "alimentacao",
                name: "Alimentação",
                kind: .expense
            ),
            makeCategory(
                id: subcategoryId,
                parentId: rootCategoryId,
                name: "Supermercado",
                kind: .expense
            ),
        ]
        let rows = [
            ReviewedImportRow(
                draft: TransactionDraft(
                    id: transactionId,
                    accountId: UUID(),
                    importBatchId: batchId,
                    signedAmount: Decimal(string: "-42.50") ?? 0,
                    occurredAt: occurredAt,
                    description: "Mercado",
                    notes: "Compra",
                    externalId: "FIT-123"
                ),
                categoryId: rootCategoryId,
                subcategoryId: subcategoryId
            ),
        ]
        let pendingBatches = [
            PendingImportBatch(
                batch: ImportBatch(
                    id: batchId,
                    sourceFilename: "extrato.ofx",
                    accountId: UUID(),
                    rowCount: 1,
                    importedAt: occurredAt,
                    createdAt: occurredAt,
                    updatedAt: occurredAt
                ),
                importFormat: .ofx
            ),
        ]

        let input = try ImportStore.buildCommitInput(
            idempotencyKey: key,
            reviewedRows: rows,
            pendingBatches: pendingBatches,
            categories: categories,
            cacheEntries: [
                CategorizationPendingCacheEntry(
                    descriptionHash: "hash-1",
                    normalizedDescription: "mercado",
                    categorySlug: "alimentacao",
                    subcategoryName: "Supermercado",
                    confidence: 0.92,
                    model: "openai/gpt-5.4-mini",
                    createdAt: occurredAt,
                    updatedAt: occurredAt
                ),
            ],
            corrections: [
                CategorizationPendingCorrection(
                    descriptionHash: "hash-1",
                    normalizedDescription: "mercado",
                    originalCategorySlug: "nao-classificado",
                    originalSubcategoryName: nil,
                    correctedCategorySlug: "alimentacao",
                    correctedSubcategoryName: "Supermercado",
                    transactionId: transactionId,
                    createdAt: occurredAt
                ),
            ]
        )
        let request = CommitImportRequest(input: input)

        #expect(input.idempotencyKey == key)
        #expect(input.batches.first?.importFormat == .ofx)
        #expect(input.rows.first?.categorySlug == "alimentacao")
        #expect(input.rows.first?.subcategoryId == subcategoryId)
        #expect(input.rows.first?.amount == Decimal(string: "42.50"))
        #expect(request.pIdempotencyKey == key)
        #expect(request.pTransactions.first?.amountCents == 4_250)
        #expect(request.pCacheEntries.first?.categorySlug == "alimentacao")
        #expect(request.pCacheEntries.first?.subcategoryName == "Supermercado")
        #expect(request.pCorrections.first?.originalCategorySlug == "nao-classificado")
        #expect(request.pCorrections.first?.correctedCategorySlug == "alimentacao")
        #expect(request.pCorrections.first?.correctedSubcategoryName == "Supermercado")
    }

    @Test("Faz refresh dos read models após commit remoto bem-sucedido")
    func refreshesAffectedReadModelsAfterCommit() async throws {
        let institution = makeInstitution(
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.checking],
            importFormats: [.ofx]
        )
        let account = Account(
            id: UUID(),
            type: .checking,
            initialBalance: 0,
            archived: false,
            institutionId: institution.id,
            createdAt: Date(),
            updatedAt: Date()
        )
        let batch = ImportBatch(
            id: UUID(),
            sourceFilename: "extrato.ofx",
            accountId: account.id,
            rowCount: 1,
            importedAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let remoteImports = RecordingImportRemoteRepository(
            batches: [batch],
            commitResult: ImportCommitResult(
                batchIds: [batch.id],
                importedRowCount: 1,
                duplicateRows: []
            )
        )
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [
                makeCategory(slug: "nao-classificado", name: "Não Classificado", kind: .expense),
            ]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: StaticAccountRemoteRepository(
                snapshot: AccountRemoteSnapshot(
                    accounts: [account],
                    bankDetails: [],
                    creditCards: []
                )
            ),
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty),
            remoteTransactions: StaticTransactionRemoteRepository(page: .empty),
            remoteImports: remoteImports
        )
        let store = ImportStore(container: container)

        let result = try await store.commitReviewedImport(
            input: ImportCommitInput(
                idempotencyKey: UUID(),
                batches: [],
                rows: [],
                cacheEntries: [],
                corrections: []
            )
        )

        #expect(result.batchIds == [batch.id])
        #expect(store.batches == [batch])
        #expect(store.accounts.map(\.id) == [account.id])
        #expect(await remoteImports.recordedInputs().count == 1)
    }
}

private actor FakeImportRemoteStore: ImportRemoteStore {
    let batches: [ImportBatchRecordRow]
    let commitResponse: ImportCommitResponse
    let deleteResponse: ImportMutationResponse

    init(
        batches: [ImportBatchRecordRow] = [],
        commitResponse: ImportCommitResponse = ImportCommitResponse(
            ok: true,
            code: nil,
            importedBatchIds: [],
            importedRowCount: 0,
            duplicateRows: []
        ),
        deleteResponse: ImportMutationResponse = .init(ok: true, code: nil)
    ) {
        self.batches = batches
        self.commitResponse = commitResponse
        self.deleteResponse = deleteResponse
    }

    func fetchBatches() async throws -> [ImportBatchRecordRow] {
        batches
    }

    func commitImport(request _: CommitImportRequest) async throws -> ImportCommitResponse {
        commitResponse
    }

    func deleteImportBatch(request _: DeleteImportBatchRequest) async throws -> ImportMutationResponse {
        deleteResponse
    }
}

private actor RecordingImportRemoteRepository: ImportRemoteRepositoryProtocol {
    private let batches: [ImportBatch]
    private let commitResult: ImportCommitResult
    private var inputs: [ImportCommitInput] = []

    init(
        batches: [ImportBatch],
        commitResult: ImportCommitResult
    ) {
        self.batches = batches
        self.commitResult = commitResult
    }

    func loadBatches() async throws -> [ImportBatch] {
        batches
    }

    func commit(input: ImportCommitInput) async throws -> ImportCommitResult {
        inputs.append(input)
        return commitResult
    }

    func delete(batchId _: UUID) async throws {}

    func recordedInputs() -> [ImportCommitInput] {
        inputs
    }
}

private func makeInstitution(
    id: UUID = UUID(),
    code: String,
    name: String,
    kind: InstitutionKind,
    accountTypes: Set<AccountType>,
    importFormats: Set<InstitutionImportFormat>
) -> Institution {
    Institution(
        id: id,
        code: code,
        name: name,
        kind: kind,
        capabilities: InstitutionCapabilities(
            supportedAccountTypes: accountTypes,
            supportedImportFormats: importFormats
        ),
        createdAt: Date(),
        updatedAt: Date()
    )
}

private func makeCategory(
    id: UUID = UUID(),
    parentId: UUID? = nil,
    slug: String? = nil,
    name: String,
    kind: CategoryKind
) -> GranaApp.Category {
    GranaApp.Category(
        id: id,
        parentId: parentId,
        name: name,
        kind: kind,
        slug: slug,
        createdAt: Date()
    )
}
