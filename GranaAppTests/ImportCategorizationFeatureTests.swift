import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("ImportCategorizationFeature")
struct ImportCategorizationFeatureTests {
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
            isReviewed: false
        )

        let store = TestStore(initialState: ImportCategorizationFeature.State()) {
            ImportCategorizationFeature()
        } withDependencies: {
            $0.importCategorizationClient.loadContext = {
                ImportCategorizationContext(
                    categories: [category],
                    accounts: [account],
                    institutions: []
                )
            }
            $0.importCategorizationClient.classifyDrafts = { _ in [suggestion] }
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
            ImportCategorizationContext(
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
}
