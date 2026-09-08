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
            suggestions: [suggestion]
        )

        #expect(state.reviewedRows == [
            ReviewedImportRow(
                draft: draft,
                categoryId: categoryId,
                subcategoryId: subcategoryId
            ),
        ])
    }

    @Test("Aplicar correção propaga para sugestões com mesmo hash")
    func applyCorrectionPropagatesAcrossMatchingSuggestions() async {
        let oldCategoryId = UUID()
        let newCategoryId = UUID()
        let newSubcategoryId = UUID()
        let first = makeSuggestion(
            transactionId: UUID(),
            categoryId: oldCategoryId,
            subcategoryId: nil,
            descriptionHash: "same-hash",
            amount: 10
        )
        let second = makeSuggestion(
            transactionId: UUID(),
            categoryId: oldCategoryId,
            subcategoryId: nil,
            descriptionHash: "same-hash",
            amount: 20
        )

        let store = TestStore(
            initialState: ImportReviewFeature.State(
                plan: makePlan(drafts: []),
                suggestions: [first, second]
            )
        ) {
            ImportReviewFeature()
        }

        await store.send(.applyCorrection(index: 0, categoryId: newCategoryId, subcategoryId: newSubcategoryId)) {
            $0.suggestions[0].categoryId = newCategoryId
            $0.suggestions[0].subcategoryId = newSubcategoryId
            $0.suggestions[0].isReviewed = true
            $0.suggestions[1].categoryId = newCategoryId
            $0.suggestions[1].subcategoryId = newSubcategoryId
            $0.suggestions[1].isReviewed = true
        }
    }

    @Test("Revisão mantém Não Classificado no topo")
    func reviewOrderingKeepsFallbackRowsAtTop() {
        let earlier = Date(timeIntervalSince1970: 10)
        let later = Date(timeIntervalSince1970: 20)
        let fallback = makeSuggestion(
            transactionId: UUID(),
            categoryId: UUID(),
            subcategoryId: UUID(),
            descriptionHash: "fallback",
            source: .fallback,
            originalCategorySlug: nil,
            occurredAt: later,
            isReviewed: true
        )
        let regular = makeSuggestion(
            transactionId: UUID(),
            categoryId: UUID(),
            subcategoryId: nil,
            descriptionHash: "regular",
            description: "Uber",
            amount: 20,
            source: .granaAI,
            originalCategorySlug: "mobilidade",
            occurredAt: earlier
        )

        let orderedIndices = ImportReviewOrdering.orderedIndices(from: [regular, fallback])

        #expect(orderedIndices == [1, 0])
    }

    @Test("Wizard materializa revisão após classificação pronta")
    func wizardCreatesReviewStateAfterCategorizationReady() async {
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
        let account = Account(
            id: draft.accountId,
            type: .checking,
            initialBalance: 0,
            archived: false,
            institutionId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let suggestion = makeSuggestion(
            transactionId: draft.id,
            categoryId: category.id,
            subcategoryId: nil
        )

        let store = TestStore(
            initialState: ImportWizardFeature.State(
                pendingPlan: plan,
                categorization: ImportCategorizationFeature.State(
                    status: .ready(total: 1, fallback: 1),
                    suggestions: [suggestion],
                    categories: [category],
                    accounts: [account],
                    institutions: []
                )
            )
        ) {
            ImportWizardFeature()
        }

        await store.send(.categorization(.delegate(.ready))) {
            $0.review = ImportReviewFeature.State(
                plan: plan,
                suggestions: [suggestion],
                categories: [category],
                accounts: [account],
                institutions: []
            )
            $0.categorization = nil
            $0.pendingPlan = nil
            $0.phase = .reviewingCategorization
        }
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
        subcategoryId: UUID?,
        descriptionHash: String = "hash",
        description: String = "Padaria",
        amount: Decimal = Decimal(12),
        source: CategorizationSuggestion.Source = .fallback,
        originalCategorySlug: String? = nil,
        occurredAt: Date = Date(),
        isReviewed: Bool = false
    ) -> CategorizationSuggestion {
        CategorizationSuggestion(
            id: UUID(),
            transactionId: transactionId,
            descriptionHash: descriptionHash,
            normalizedDescription: description.lowercased(),
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            source: source,
            originalCategoryId: nil,
            originalSubcategoryId: nil,
            originalCategorySlug: originalCategorySlug,
            originalSubcategoryName: nil,
            transactionDescription: description,
            transactionAmount: amount,
            transactionOccurredAt: occurredAt,
            transactionAccountId: UUID(),
            transactionNotes: nil,
            transactionDestinationAccountId: nil,
            isReviewed: isReviewed
        )
    }
}
