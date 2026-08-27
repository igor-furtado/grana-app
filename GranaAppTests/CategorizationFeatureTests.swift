import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("CategorizationFeature")
struct CategorizationFeatureTests {
    @Test("Carrega contexto e sugestões ao iniciar classificação")
    func startsAndTransitionsToReady() async {
        let category = Category(
            id: UUID(),
            parentId: nil,
            name: "Não Classificado",
            kind: .expense,
            slug: "nao-classificado",
            createdAt: Date()
        )
        let account = Account(
            id: UUID(),
            type: .checking,
            initialBalance: 0,
            archived: false,
            institutionId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let draft = TransactionDraft(
            id: UUID(),
            accountId: account.id,
            importBatchId: UUID(),
            signedAmount: Decimal(string: "-10.00") ?? 0,
            occurredAt: Date(),
            description: "Padaria",
            notes: nil,
            externalId: "FIT-1"
        )
        let suggestion = CategorizationSuggestion(
            id: UUID(),
            transactionId: draft.id,
            descriptionHash: "hash",
            normalizedDescription: "padaria",
            categoryId: category.id,
            subcategoryId: nil,
            source: .fallback,
            originalCategoryId: nil,
            originalSubcategoryId: nil,
            originalCategorySlug: nil,
            originalSubcategoryName: nil,
            transactionDescription: draft.description,
            transactionAmount: Decimal(string: "10.00") ?? 0,
            transactionOccurredAt: draft.occurredAt,
            transactionAccountId: draft.accountId,
            transactionNotes: draft.notes,
            transactionDestinationAccountId: draft.destinationAccountId,
            transactionRefundOfTransactionId: draft.refundOfTransactionId,
            isReviewed: false
        )

        let store = TestStore(initialState: CategorizationFeature.State()) {
            CategorizationFeature()
        } withDependencies: {
            $0.categorizationClient.loadContext = {
                CategorizationContext(
                    categories: [category],
                    accounts: [account],
                    institutions: []
                )
            }
            $0.categorizationClient.classifyDrafts = { _ in [suggestion] }
        }

        await store.send(.start([draft])) {
            $0.status = .classifying(
                processed: 0,
                total: 1,
                message: "Preparando classificação…"
            )
            $0.suggestions = []
        }

        await store.receive(.contextLoaded(.success(
            CategorizationContext(
                categories: [category],
                accounts: [account],
                institutions: []
            )
        ))) {
            $0.categories = [category]
            $0.accounts = [account]
            $0.institutions = []
        }

        await store.receive(.suggestionsLoaded(.success([suggestion]))) {
            $0.suggestions = [suggestion]
            $0.status = .ready(total: 1, fallback: 1)
        }

        await store.receive(.delegate(.ready))
    }

    @Test("Aplicar correção propaga para sugestões com mesmo hash")
    func applyCorrectionPropagatesAcrossMatchingSuggestions() async {
        let oldCategoryId = UUID()
        let newCategoryId = UUID()
        let newSubcategoryId = UUID()
        let first = CategorizationSuggestion(
            id: UUID(),
            transactionId: UUID(),
            descriptionHash: "same-hash",
            normalizedDescription: "padaria",
            categoryId: oldCategoryId,
            subcategoryId: nil,
            source: .fallback,
            originalCategoryId: nil,
            originalSubcategoryId: nil,
            originalCategorySlug: nil,
            originalSubcategoryName: nil,
            transactionDescription: "Padaria",
            transactionAmount: 10,
            transactionOccurredAt: Date(),
            transactionAccountId: UUID(),
            transactionNotes: nil,
            transactionDestinationAccountId: nil,
            transactionRefundOfTransactionId: nil,
            isReviewed: false
        )
        let second = CategorizationSuggestion(
            id: UUID(),
            transactionId: UUID(),
            descriptionHash: "same-hash",
            normalizedDescription: "padaria",
            categoryId: oldCategoryId,
            subcategoryId: nil,
            source: .fallback,
            originalCategoryId: nil,
            originalSubcategoryId: nil,
            originalCategorySlug: nil,
            originalSubcategoryName: nil,
            transactionDescription: "Padaria",
            transactionAmount: 20,
            transactionOccurredAt: Date(),
            transactionAccountId: UUID(),
            transactionNotes: nil,
            transactionDestinationAccountId: nil,
            transactionRefundOfTransactionId: nil,
            isReviewed: false
        )

        let store = TestStore(
            initialState: CategorizationFeature.State(
                status: .ready(total: 2, fallback: 2),
                suggestions: [first, second],
                categories: [],
                accounts: [],
                institutions: []
            )
        ) {
            CategorizationFeature()
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
}
