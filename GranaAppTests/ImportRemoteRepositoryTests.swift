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
                rows: []
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
                    rows: []
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
            categories: categories
        )
        let request = CommitImportRequest(input: input)

        #expect(input.idempotencyKey == key)
        #expect(input.batches.first?.importFormat == .ofx)
        #expect(input.rows.first?.categorySlug == "alimentacao")
        #expect(input.rows.first?.subcategoryId == subcategoryId)
        #expect(input.rows.first?.amount == Decimal(string: "42.50"))
        #expect(request.pIdempotencyKey == key)
        #expect(request.pTransactions.first?.amountCents == 4250)
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
                rows: []
            )
        )

        #expect(result.batchIds == [batch.id])
        #expect(store.batches == [batch])
        #expect(store.accounts.map(\.id) == [account.id])
        #expect(await remoteImports.recordedInputs().count == 1)
    }

    @Test("Monta payload de learn apenas com classificações confirmadas válidas")
    func buildsLearningPayloadSkippingFallback() throws {
        let fallbackCategory = makeCategory(
            slug: "nao-classificado",
            name: "Não Classificado",
            kind: .expense
        )
        let foodCategory = makeCategory(
            slug: "alimentacao",
            name: "Alimentação",
            kind: .expense
        )
        let bakerySubcategory = makeCategory(
            parentId: foodCategory.id,
            name: "Padarias",
            kind: .expense
        )
        let draftToLearn = TransactionDraft(
            id: UUID(),
            accountId: UUID(),
            importBatchId: UUID(),
            signedAmount: Decimal(string: "-18.90") ?? 0,
            occurredAt: Date(),
            description: "PADARIA CENTRAL",
            notes: nil,
            externalId: "FIT-1"
        )
        let draftToSkip = TransactionDraft(
            id: UUID(),
            accountId: UUID(),
            importBatchId: UUID(),
            signedAmount: Decimal(string: "-42.00") ?? 0,
            occurredAt: Date(),
            description: "LANCAMENTO DESCONHECIDO",
            notes: nil,
            externalId: "FIT-2"
        )
        let builtRequest = try GranaAIFeedbackService.buildLearningRequest(
            suggestions: [
                makeSuggestion(
                    draft: draftToLearn,
                    categoryId: foodCategory.id,
                    subcategoryId: bakerySubcategory.id
                ),
                makeSuggestion(
                    draft: draftToSkip,
                    categoryId: fallbackCategory.id,
                    subcategoryId: nil
                ),
            ],
            categories: [fallbackCategory, foodCategory, bakerySubcategory]
        )
        let request = try #require(builtRequest)

        #expect(request.version == GranaAIContract.version)
        #expect(request.confirmedClassifications.count == 1)
        #expect(request.confirmedClassifications.first?.description == "PADARIA CENTRAL")
        #expect(request.confirmedClassifications.first?.categoryId == "alimentacao")
        #expect(request.confirmedClassifications.first?.subcategoryId == "padarias")
    }

    @Test("Executa learn antes do commit remoto")
    func learnsBeforeRemoteCommit() async throws {
        let recorder = EventRecorder()
        let batchId = UUID()
        let learnRequest = GranaAIClassificationLearningRequest(
            version: GranaAIContract.version,
            taxonomy: .init(categories: []),
            confirmedClassifications: [
                .init(description: "PADARIA CENTRAL", categoryId: "alimentacao", subcategoryId: "padarias"),
            ]
        )
        let remoteImports = RecordingImportRemoteRepository(
            batches: [],
            commitResult: ImportCommitResult(
                batchIds: [batchId],
                importedRowCount: 1,
                duplicateRows: []
            ),
            recorder: recorder
        )
        let granaAI = RecordingGranaAIClient(recorder: recorder)
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: []),
            remoteImports: remoteImports,
            granaAI: granaAI
        )
        let store = ImportStore(container: container)

        _ = try await store.commitReviewedImport(
            input: ImportCommitInput(
                idempotencyKey: UUID(),
                batches: [],
                rows: []
            ),
            learnRequest: learnRequest
        )

        let events = await recorder.snapshot()
        #expect(events == ["learn", "commit"])
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
    private let recorder: EventRecorder?
    private var inputs: [ImportCommitInput] = []

    init(
        batches: [ImportBatch],
        commitResult: ImportCommitResult,
        recorder: EventRecorder? = nil
    ) {
        self.batches = batches
        self.commitResult = commitResult
        self.recorder = recorder
    }

    func loadBatches() async throws -> [ImportBatch] {
        batches
    }

    func commit(input: ImportCommitInput) async throws -> ImportCommitResult {
        await recorder?.record("commit")
        inputs.append(input)
        return commitResult
    }

    func delete(batchId _: UUID) async throws {}

    func recordedInputs() -> [ImportCommitInput] {
        inputs
    }
}

private actor RecordingGranaAIClient: GranaAIClassificationClientProtocol {
    private let recorder: EventRecorder?
    private var learnRequests: [GranaAIClassificationLearningRequest] = []

    init(recorder: EventRecorder? = nil) {
        self.recorder = recorder
    }

    func classify(_ request: GranaAIClassificationRequest) async throws -> GranaAIClassificationResponse {
        .init(version: request.version, results: [])
    }

    func learn(_ request: GranaAIClassificationLearningRequest) async throws {
        await recorder?.record("learn")
        learnRequests.append(request)
    }

    func recordedLearnRequests() -> [GranaAIClassificationLearningRequest] {
        learnRequests
    }
}

private actor EventRecorder {
    private var events: [String] = []

    func record(_ value: String) {
        events.append(value)
    }

    func snapshot() -> [String] {
        events
    }
}

private func makeSuggestion(
    draft: TransactionDraft,
    categoryId: UUID,
    subcategoryId: UUID?
) -> CategorizationSuggestion {
    CategorizationSuggestion(
        id: UUID(),
        transactionId: draft.id,
        descriptionHash: "hash-\(draft.id.uuidString)",
        normalizedDescription: draft.description,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        source: .granaAI,
        originalCategoryId: nil,
        originalSubcategoryId: nil,
        originalCategorySlug: nil,
        originalSubcategoryName: nil,
        transactionDescription: draft.description,
        transactionAmount: abs(draft.signedAmount),
        transactionOccurredAt: draft.occurredAt,
        transactionAccountId: draft.accountId,
        transactionNotes: draft.notes,
        transactionDestinationAccountId: draft.destinationAccountId,
        transactionRefundOfTransactionId: draft.refundOfTransactionId,
        isReviewed: true
    )
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
