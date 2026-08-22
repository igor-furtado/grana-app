import Foundation
import Testing
@testable import GranaAi

/// Garante que a referência local do catálogo global e o mapping
/// `slug → CategoryIcon` não derivam.
///
/// Sem isso: alguém adiciona uma raiz na migration do catálogo e atualiza esta
/// referência, mas esquece de incluir o slug em `CategoryIcon+Slug.swift`. A UI
/// renderiza sem ícone — silenciosamente. Esse teste pega o drift em CI.
@Suite("Category catalog reference ↔ CategoryIcon+Slug consistency")
struct CategoryCatalogReferenceConsistencyTests {
    @Test("toda raiz do catálogo referenciado tem ícone resolvido pelo mapping")
    func everyCatalogRootHasIcon() {
        for definition in CategoryCatalogReferenceData.categories {
            #expect(
                CategoryIcon.forSlug(definition.slug) != nil,
                "Slug '\(definition.slug)' está na referência do catálogo mas não tem entrada em CategoryIcon+Slug.swift"
            )
        }
    }

    @Test("slugs do catálogo referenciado são únicos")
    func slugsAreUnique() {
        let slugs = CategoryCatalogReferenceData.categories.map(\.slug)
        let uniqueSlugs = Set(slugs)
        #expect(slugs.count == uniqueSlugs.count, "Slug duplicado na referência do catálogo")
    }
}
