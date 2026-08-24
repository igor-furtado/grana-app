import Foundation
import Testing
@testable import GranaApp

@Suite("CategorizationPrompt")
struct CategorizationPromptTests {
    @Test("buildRequest preserva taxonomia e contas do app sem few-shots")
    func buildRequestPreservesClientPayload() throws {
        let request = CategorizationPrompt.buildRequest(
            items: [
                .init(
                    index: 0,
                    description: "mercado",
                    sign: "expense",
                    accountContext: "Conta Corrente",
                    sourceHint: nil
                ),
            ],
            categories: [
                .init(
                    id: UUID(),
                    slug: "alimentacao",
                    name: "Alimentação",
                    kind: "expense",
                    subcategories: [
                        .init(id: UUID(), name: "Supermercados"),
                    ]
                ),
            ],
            ownAccounts: [
                .init(
                    name: "Banco Inter",
                    typeDisplay: "Conta Corrente",
                    institutionName: "Inter"
                ),
            ],
            taxonomyVersion: 7
        )

        #expect(request.taxonomyVersion == 7)
        #expect(request.items.count == 1)
        #expect(request.categories.count == 1)
        #expect(request.ownAccounts.count == 1)
        #expect(request.categories[0].slug == "alimentacao")
    }

    @Test("parseResults lê resposta JSON estruturada do backend")
    func parseResultsStructuredBackendJSON() throws {
        let payload = """
        {"results":[{"index":0,"description_hash":"abc123","normalized_description":"mercado","category_slug":"alimentacao","subcategory_name":"Supermercados","confidence":0.91,"source":"ai"}],"metadata":{"provider":"openai","model":"gpt-5.4-mini","from_cache":0,"from_ai":1,"fallback_count":0}}
        """

        let results = try CategorizationPrompt.parseResults(from: Data(payload.utf8))

        #expect(results.count == 1)
        #expect(results[0].index == 0)
        #expect(results[0].descriptionHash == "abc123")
        #expect(results[0].normalizedDescription == "mercado")
        #expect(results[0].categorySlug == "alimentacao")
        #expect(results[0].subcategoryName == "Supermercados")
        #expect(results[0].confidence == 0.91)
        #expect(results[0].source == .ai)
    }
}
