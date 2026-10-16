import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("ImportCommitClient")
struct ImportCommitClientTests {
    @Test("Commit revisado monta payload financeiro e feedback de classificação")
    func reviewedImportCommitBuildsInputAndLearningRequest() async throws {
        let batchId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000201"))
        let transactionId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000202"))
        let accountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000203"))
        let idempotencyKey = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000204"))
        let importedAt = Date(timeIntervalSince1970: 1_788_000_000)
        let category = try Category(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000205")),
            parentId: nil,
            name: "Alimentação",
            kind: .expense,
            slug: "alimentacao",
            createdAt: importedAt
        )
        let fallback = try Category(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000206")),
            parentId: nil,
            name: "Não Classificado",
            kind: .expense,
            slug: "nao-classificado",
            createdAt: importedAt
        )
        let draft = TransactionDraft(
            id: transactionId,
            accountId: accountId,
            importBatchId: batchId,
            signedAmount: Decimal(-42),
            occurredAt: importedAt,
            description: "Padaria",
            notes: nil,
            externalId: "FIT-1"
        )
        let suggestion = CategorizationSuggestion(
            id: UUID(),
            transactionId: transactionId,
            descriptionHash: "padaria",
            normalizedDescription: "padaria",
            categoryId: category.id,
            subcategoryId: nil,
            source: .fallback,
            originalCategoryId: nil,
            originalSubcategoryId: nil,
            originalCategorySlug: nil,
            originalSubcategoryName: nil,
            transactionDescription: "Padaria",
            transactionAmount: Decimal(42),
            transactionOccurredAt: importedAt,
            transactionAccountId: accountId,
            transactionNotes: nil,
            transactionDestinationAccountId: nil,
            isReviewed: true
        )
        let expectedResult = ImportCommitResult(
            batchIds: [batchId],
            importedRowCount: 1,
            duplicateRows: []
        )
        let remoteImports = ImportCommitRecordingRemoteRepository(commitResult: expectedResult)
        let granaAI = ImportCommitRecordingGranaAIClient()
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: []),
            remoteImports: remoteImports,
            granaAI: granaAI
        )
        let client = ImportCommitClient.live(container: container)

        let result = try await client.commitReviewedImport(
            ReviewedImportCommit(
                idempotencyKey: idempotencyKey,
                reviewedRows: [
                    ReviewedImportRow(
                        draft: draft,
                        categoryId: category.id,
                        subcategoryId: nil
                    ),
                ],
                pendingBatches: [
                    PendingImportBatch(
                        batch: ImportBatch(
                            id: batchId,
                            sourceFilename: "extrato.ofx",
                            accountId: accountId,
                            rowCount: 1,
                            importedAt: importedAt,
                            createdAt: importedAt,
                            updatedAt: importedAt
                        ),
                        importFormat: .ofx
                    ),
                ],
                categories: [category, fallback],
                suggestions: [suggestion]
            )
        )

        #expect(result == expectedResult)
        let input = try #require(await remoteImports.recordedInputs().first)
        #expect(input.idempotencyKey == idempotencyKey)
        #expect(input.rows.first?.transactionId == transactionId)
        #expect(input.rows.first?.categorySlug == "alimentacao")
        #expect(input.rows.first?.amount == Decimal(42))
        #expect(await granaAI.recordedLearnRequests().first?.confirmedClassifications.count == 1)
    }
}

private actor ImportCommitRecordingRemoteRepository: ImportRemoteRepositoryProtocol {
    private let commitResult: ImportCommitResult
    private var inputs: [ImportCommitInput] = []

    init(commitResult: ImportCommitResult) {
        self.commitResult = commitResult
    }

    func loadBatches() async throws -> [ImportBatch] {
        []
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

private actor ImportCommitRecordingGranaAIClient: GranaAIClassificationClientProtocol {
    private var learnRequests: [GranaAIClassificationLearningRequest] = []

    func classify(_ request: GranaAIClassificationRequest) async throws -> GranaAIClassificationResponse {
        .init(version: request.version, results: [])
    }

    func learn(_ request: GranaAIClassificationLearningRequest) async throws {
        learnRequests.append(request)
    }

    func recordedLearnRequests() -> [GranaAIClassificationLearningRequest] {
        learnRequests
    }
}
