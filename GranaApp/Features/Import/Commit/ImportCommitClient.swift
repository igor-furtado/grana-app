import ComposableArchitecture
import Foundation

struct ReviewedImportCommit: Equatable {
    var idempotencyKey: UUID
    var reviewedRows: [ReviewedImportRow]
    var pendingBatches: [PendingImportBatch]
    var categories: [Category]
    var suggestions: [CategorizationSuggestion]
}

struct ImportCommitClient {
    var commitReviewedImport: @Sendable (_ commit: ReviewedImportCommit) async throws -> ImportCommitResult

    static func live(container: AppContainer) -> ImportCommitClient {
        ImportCommitClient { commit in
            let input = try ImportCommitBuilder.buildInput(
                idempotencyKey: commit.idempotencyKey,
                reviewedRows: commit.reviewedRows,
                pendingBatches: commit.pendingBatches,
                categories: commit.categories
            )
            let learnRequest = try ImportCommitBuilder.buildLearnRequest(
                suggestions: commit.suggestions,
                categories: commit.categories
            )
            if let learnRequest {
                try await container.categorizationFeedback.learnConfirmedClassifications(request: learnRequest)
            }
            return try await container.remoteImports.commit(input: input)
        }
    }
}

extension ImportCommitClient: DependencyKey {
    static let liveValue = ImportCommitClient(
        commitReviewedImport: unimplemented("ImportCommitClient.commitReviewedImport")
    )

    static let testValue = ImportCommitClient(
        commitReviewedImport: unimplemented("ImportCommitClient.commitReviewedImport")
    )
}

extension DependencyValues {
    var importCommitClient: ImportCommitClient {
        get { self[ImportCommitClient.self] }
        set { self[ImportCommitClient.self] = newValue }
    }
}

enum ImportCommitBuilder {
    nonisolated static func buildInput(
        idempotencyKey: UUID,
        reviewedRows: [ReviewedImportRow],
        pendingBatches: [PendingImportBatch],
        categories: [Category]
    ) throws -> ImportCommitInput {
        guard let fallbackSlug = categories.rootCategory(slug: "nao-classificado")?.slug else {
            throw ImportError.unclassifiedCategoryMissing
        }

        let rootSlugsById = Dictionary(
            uniqueKeysWithValues: categories
                .filter { $0.parentId == nil }
                .compactMap { category in
                    category.slug.map { (category.id, $0) }
                }
        )
        let categoryKindsById = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.id, $0.kind) }
        )

        let batchIds = Set(pendingBatches.map(\.batch.id))
        let rows = reviewedRows
            .filter { batchIds.contains($0.draft.importBatchId) }
            .map { row in
                let categorySlug = row.categoryId.flatMap { rootSlugsById[$0] } ?? fallbackSlug
                let isTransfer = row.categoryId.flatMap { categoryKindsById[$0] } == .transfer
                return ImportTransactionCommitInput(
                    transactionId: row.draft.id,
                    batchId: row.draft.importBatchId,
                    accountId: row.accountId ?? row.draft.accountId,
                    categorySlug: categorySlug,
                    subcategoryId: isTransfer ? nil : row.subcategoryId,
                    destinationAccountId: row.destinationAccountId ?? row.draft.destinationAccountId,
                    amount: abs(row.draft.signedAmount),
                    occurredAt: row.draft.occurredAt,
                    originOccurredAt: row.draft.originOccurredAt,
                    purchaseType: row.draft.purchaseType,
                    installmentIndex: row.draft.installmentIndex,
                    installmentCount: row.draft.installmentCount,
                    description: row.draft.description,
                    notes: row.draft.notes,
                    externalId: row.draft.externalId
                )
            }

        return ImportCommitInput(
            idempotencyKey: idempotencyKey,
            batches: pendingBatches.map {
                ImportBatchCommitInput(
                    batchId: $0.batch.id,
                    sourceFilename: $0.batch.sourceFilename,
                    accountId: $0.batch.accountId,
                    importedAt: $0.batch.importedAt,
                    importFormat: $0.importFormat
                )
            },
            rows: rows
        )
    }

    nonisolated static func buildLearnRequest(
        suggestions: [CategorizationSuggestion],
        categories: [Category]
    ) throws -> GranaAIClassificationLearningRequest? {
        try GranaAIFeedbackService.buildLearningRequest(
            suggestions: suggestions,
            categories: categories
        )
    }
}
