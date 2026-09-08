import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("ImportReviewFeature")
struct ImportReviewFeatureTests {
    @Test("Revisão combina drafts do plano com sugestões confirmadas")
    func reviewedRowsUsePlanDraftsAndCurrentSuggestions() throws {
        let categoryId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let subcategoryId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000102"))
        let draft = makeDraft()
        let suggestion = makeSuggestion(
            transactionId: draft.id,
            categoryId: categoryId,
            subcategoryId: subcategoryId
        )

        let state = ImportReviewFeature.State(
            plan: makePlan(drafts: [draft]),
            categorization: ImportCategorizationFeature.State(suggestions: [suggestion])
        )

        #expect(state.reviewedRows == [
            ReviewedImportRow(
                draft: draft,
                categoryId: categoryId,
                subcategoryId: subcategoryId
            ),
        ])
    }

    @Test("Revisão inicia classificação e propaga pronto")
    func reviewStartsCategorizationAndPropagatesReady() async {
        let draft = makeDraft()
        let plan = makePlan(drafts: [draft])
        let category = Category(
            id: UUID(),
            parentId: nil,
            name: "Não Classificado",
            kind: .expense,
            slug: "nao-classificado",
            createdAt: Date()
        )
        let suggestion = makeSuggestion(
            transactionId: draft.id,
            categoryId: category.id,
            subcategoryId: nil
        )
        let store = TestStore(initialState: ImportReviewFeature.State(plan: plan)) {
            ImportReviewFeature()
        } withDependencies: {
            $0.importCategorizationClient.loadContext = {
                ImportCategorizationContext(categories: [category], accounts: [], institutions: [])
            }
            $0.importCategorizationClient.classifyDrafts = { drafts in
                #expect(drafts == [draft])
                return [suggestion]
            }
        }

        await store.send(.start)

        await store.receive(.categorization(.start([draft]))) {
            $0.categorization.status = .classifying(
                processed: 0,
                total: 1,
                message: "Preparando classificação…"
            )
            $0.categorization.suggestions = []
        }

        await store.receive(.categorization(.contextLoaded(.success(
            ImportCategorizationContext(categories: [category], accounts: [], institutions: [])
        )))) {
            $0.categorization.categories = [category]
            $0.categorization.accounts = []
            $0.categorization.institutions = []
        }

        await store.receive(.categorization(.suggestionsLoaded(.success([suggestion])))) {
            $0.categorization.suggestions = [suggestion]
            $0.categorization.status = .ready(total: 1, fallback: 1)
        }

        await store.receive(.categorization(.delegate(.ready)))
        await store.receive(.delegate(.ready))
    }

    private func makePlan(drafts: [TransactionDraft]) -> PendingImportPlan {
        PendingImportPlan(
            batches: [
                PendingImportBatch(
                    batch: ImportBatch(
                        id: UUID(),
                        sourceFilename: "extrato.ofx",
                        accountId: UUID(),
                        rowCount: drafts.count,
                        importedAt: Date(),
                        createdAt: Date(),
                        updatedAt: Date()
                    ),
                    importFormat: .ofx
                ),
            ],
            drafts: drafts,
            impact: ImportPlanImpact(
                importedRowCount: drafts.count,
                skippedDuplicateRowCount: 0,
                skippedDeselectedRowCount: 0,
                statementBalanceDraftCount: 0
            )
        )
    }

    private func makeDraft() -> TransactionDraft {
        TransactionDraft(
            id: UUID(),
            accountId: UUID(),
            importBatchId: UUID(),
            signedAmount: Decimal(-12),
            occurredAt: Date(),
            description: "Padaria",
            notes: nil,
            externalId: "FIT-1"
        )
    }

    private func makeSuggestion(
        transactionId: UUID,
        categoryId: UUID,
        subcategoryId: UUID?
    ) -> CategorizationSuggestion {
        CategorizationSuggestion(
            id: UUID(),
            transactionId: transactionId,
            descriptionHash: "hash",
            normalizedDescription: "padaria",
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            source: .fallback,
            originalCategoryId: nil,
            originalSubcategoryId: nil,
            originalCategorySlug: nil,
            originalSubcategoryName: nil,
            transactionDescription: "Padaria",
            transactionAmount: Decimal(12),
            transactionOccurredAt: Date(),
            transactionAccountId: UUID(),
            transactionNotes: nil,
            transactionDestinationAccountId: nil,
            isReviewed: false
        )
    }
}
