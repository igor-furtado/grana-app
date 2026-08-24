import Foundation
import Testing
@testable import GranaApp

@Suite("CategorizationService")
struct CategorizationServiceTests {
    @MainActor
    @Test("Classifica drafts localmente como Não Classificado")
    func classifiesDraftsWithLocalFallback() async throws {
        let fallbackCategory = Category(
            id: UUID(),
            parentId: nil,
            name: "Não Classificado",
            kind: .expense,
            slug: "nao-classificado",
            createdAt: Date()
        )
        let service = CategorizationService(
            categories: StaticCategoryCatalogRepository(categories: [fallbackCategory])
        )
        let draft = TransactionDraft(
            id: UUID(),
            accountId: UUID(),
            importBatchId: UUID(),
            signedAmount: -42,
            occurredAt: Date(),
            description: "Mercado Exemplo",
            notes: nil,
            externalId: "fitid-1"
        )

        let result = try await service.classifyDrafts([draft])
        let suggestion = try #require(result.suggestions.first)

        #expect(result.suggestions.count == 1)
        #expect(suggestion.categoryId == fallbackCategory.id)
        #expect(suggestion.subcategoryId == nil)
        #expect(suggestion.source == CategorizationSuggestion.Source.fallback)
        #expect(suggestion.transactionId == draft.id)
    }
}
