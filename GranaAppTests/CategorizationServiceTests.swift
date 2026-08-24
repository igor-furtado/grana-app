import Foundation
import Testing
@testable import GranaApp

@Suite("CategorizationService")
struct CategorizationServiceTests {
    @MainActor
    @Test("Classifica drafts localmente como Não Classificado")
    func classifiesDraftsWithLocalFallback() async throws {
        let fallbackCategory = makeRootCategory(name: "Não Classificado", slug: "nao-classificado")
        let service = CategorizationService(
            categories: StaticCategoryCatalogRepository(categories: [fallbackCategory])
        )
        let draft = makeDraft(description: "Mercado Exemplo")

        let result = try await service.classifyDrafts([draft])
        let suggestion = try #require(result.suggestions.first)

        #expect(result.suggestions.count == 1)
        #expect(suggestion.categoryId == fallbackCategory.id)
        #expect(suggestion.subcategoryId == nil)
        #expect(suggestion.source == CategorizationSuggestion.Source.fallback)
        #expect(suggestion.transactionId == draft.id)
    }

    @MainActor
    @Test("Usa sugestão classificada do GranaAI quando a taxonomia é válida")
    func usesGranaAIClassificationWhenSelectionIsValid() async throws {
        let fallbackCategory = makeRootCategory(name: "Não Classificado", slug: "nao-classificado")
        let foodCategory = makeRootCategory(name: "Alimentação", slug: "alimentacao")
        let bakerySubcategory = makeSubcategory(name: "Padarias", parentId: foodCategory.id)
        let draft = makeDraft(description: "PADARIA CENTRAL", signedAmount: -18.90)
        let client = FakeGranaAIClient(
            response: .init(
                version: GranaAIContract.version,
                results: [
                    .init(
                        transactionId: draft.id.uuidString,
                        outcome: .classified(categoryId: "alimentacao", subcategoryId: "padarias")
                    ),
                ]
            )
        )
        let service = CategorizationService(
            categories: StaticCategoryCatalogRepository(
                categories: [fallbackCategory, foodCategory, bakerySubcategory]
            ),
            granaAI: client
        )

        let result = try await service.classifyDrafts([draft])
        let suggestion = try #require(result.suggestions.first)
        let request = try await #require(client.recordedRequests.first)

        #expect(suggestion.categoryId == foodCategory.id)
        #expect(suggestion.subcategoryId == bakerySubcategory.id)
        #expect(suggestion.source == .granaAI)
        #expect(request.transactions.first?.amountInMinorUnits == -1890)
        #expect(request.taxonomy.categories.contains { $0.id == "alimentacao" })
        #expect(
            request.taxonomy.categories
                .first { $0.id == "alimentacao" }?
                .subcategories
                .contains { $0.id == "padarias" } == true
        )
    }

    @MainActor
    @Test("Cai para Não Classificado quando o GranaAI retorna categoria fora da taxonomia")
    func fallsBackWhenGranaAIReturnsUnknownSelection() async throws {
        let fallbackCategory = makeRootCategory(name: "Não Classificado", slug: "nao-classificado")
        let foodCategory = makeRootCategory(name: "Alimentação", slug: "alimentacao")
        let draft = makeDraft(description: "PADARIA CENTRAL")
        let client = FakeGranaAIClient(
            response: .init(
                version: GranaAIContract.version,
                results: [
                    .init(
                        transactionId: draft.id.uuidString,
                        outcome: .classified(categoryId: "categoria-inexistente", subcategoryId: "padarias")
                    ),
                ]
            )
        )
        let service = CategorizationService(
            categories: StaticCategoryCatalogRepository(categories: [fallbackCategory, foodCategory]),
            granaAI: client
        )

        let result = try await service.classifyDrafts([draft])
        let suggestion = try #require(result.suggestions.first)

        #expect(suggestion.categoryId == fallbackCategory.id)
        #expect(suggestion.subcategoryId == nil)
        #expect(suggestion.source == .fallback)
    }

    @MainActor
    @Test("Cai para Não Classificado quando o GranaAI falha")
    func fallsBackWhenGranaAIFails() async throws {
        let fallbackCategory = makeRootCategory(name: "Não Classificado", slug: "nao-classificado")
        let draft = makeDraft(description: "PADARIA CENTRAL")
        let client = FakeGranaAIClient(error: GranaAIProcessClientError.timedOut)
        let service = CategorizationService(
            categories: StaticCategoryCatalogRepository(categories: [fallbackCategory]),
            granaAI: client
        )

        let result = try await service.classifyDrafts([draft])
        let suggestion = try #require(result.suggestions.first)

        #expect(suggestion.categoryId == fallbackCategory.id)
        #expect(suggestion.source == .fallback)
    }
}

private func makeRootCategory(name: String, slug: String) -> GranaApp.Category {
    GranaApp.Category(
        id: UUID(),
        parentId: nil,
        name: name,
        kind: .expense,
        slug: slug,
        createdAt: Date()
    )
}

private func makeSubcategory(name: String, parentId: UUID) -> GranaApp.Category {
    GranaApp.Category(
        id: UUID(),
        parentId: parentId,
        name: name,
        kind: .expense,
        slug: nil,
        createdAt: Date()
    )
}

private func makeDraft(
    description: String,
    signedAmount: Decimal = -42
) -> TransactionDraft {
    TransactionDraft(
        id: UUID(),
        accountId: UUID(),
        importBatchId: UUID(),
        signedAmount: signedAmount,
        occurredAt: Date(),
        description: description,
        notes: nil,
        externalId: "fitid-1"
    )
}

private actor FakeGranaAIClient: GranaAIClassificationClientProtocol {
    private let response: GranaAIClassificationResponse?
    private let error: Error?
    private(set) var recordedRequests: [GranaAIClassificationRequest] = []
    private(set) var recordedLearnRequests: [GranaAIClassificationLearningRequest] = []

    init(
        response: GranaAIClassificationResponse? = nil,
        error: Error? = nil
    ) {
        self.response = response
        self.error = error
    }

    func classify(_ request: GranaAIClassificationRequest) async throws -> GranaAIClassificationResponse {
        recordedRequests.append(request)
        if let error {
            throw error
        }
        return try #require(response)
    }

    func learn(_ request: GranaAIClassificationLearningRequest) async throws {
        recordedLearnRequests.append(request)
        if let error {
            throw error
        }
    }
}
