import Foundation

nonisolated struct GranaAITaxonomyMapping {
    let requestTaxonomy: GranaAIClassificationRequest.Taxonomy

    private let categoryIdsByExternalId: [String: UUID]
    private let subcategoryIdsBySelection: [SelectionKey: UUID]
    private let externalCategoryIdsByLocalId: [UUID: String]
    private let externalSubcategoryIdsByLocalId: [UUID: String]

    init(categories: [Category]) {
        let roots = categories
            .filter { $0.parentId == nil }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        var categoryIdsByExternalId: [String: UUID] = [:]
        var subcategoryIdsBySelection: [SelectionKey: UUID] = [:]
        var externalCategoryIdsByLocalId: [UUID: String] = [:]
        var externalSubcategoryIdsByLocalId: [UUID: String] = [:]

        let requestCategories = roots.compactMap { root -> GranaAIClassificationRequest.Category? in
            guard let rootSlug = root.slug, !rootSlug.isEmpty else {
                return nil
            }
            categoryIdsByExternalId[rootSlug] = root.id
            externalCategoryIdsByLocalId[root.id] = rootSlug

            let children = categories
                .filter { $0.parentId == root.id }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            let requestSubcategories = children.map { child in
                let externalId = GranaAITaxonomyID.slug(from: child.name)
                subcategoryIdsBySelection[
                    SelectionKey(categoryExternalId: rootSlug, subcategoryExternalId: externalId)
                ] = child.id
                externalSubcategoryIdsByLocalId[child.id] = externalId
                return GranaAIClassificationRequest.Subcategory(
                    id: externalId,
                    name: child.name
                )
            }

            return GranaAIClassificationRequest.Category(
                id: rootSlug,
                name: root.name,
                subcategories: requestSubcategories
            )
        }

        self.requestTaxonomy = .init(categories: requestCategories)
        self.categoryIdsByExternalId = categoryIdsByExternalId
        self.subcategoryIdsBySelection = subcategoryIdsBySelection
        self.externalCategoryIdsByLocalId = externalCategoryIdsByLocalId
        self.externalSubcategoryIdsByLocalId = externalSubcategoryIdsByLocalId
    }

    func resolve(categoryId: String, subcategoryId: String?) -> (categoryId: UUID, subcategoryId: UUID?)? {
        guard let localCategoryId = categoryIdsByExternalId[categoryId] else {
            return nil
        }

        guard let subcategoryId else {
            return (localCategoryId, nil)
        }

        let key = SelectionKey(
            categoryExternalId: categoryId,
            subcategoryExternalId: subcategoryId
        )
        guard let localSubcategoryId = subcategoryIdsBySelection[key] else {
            return nil
        }

        return (localCategoryId, localSubcategoryId)
    }

    func externalSelection(
        categoryId: UUID,
        subcategoryId: UUID?
    ) -> (categoryId: String, subcategoryId: String?)? {
        guard let externalCategoryId = externalCategoryIdsByLocalId[categoryId] else {
            return nil
        }

        guard let subcategoryId else {
            return (externalCategoryId, nil)
        }

        guard let externalSubcategoryId = externalSubcategoryIdsByLocalId[subcategoryId] else {
            return nil
        }

        return (externalCategoryId, externalSubcategoryId)
    }
}

nonisolated enum GranaAITaxonomyID {
    static func slug(from value: String) -> String {
        value
            .replacingOccurrences(of: "º", with: "o")
            .replacingOccurrences(of: "ª", with: "a")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}

private struct SelectionKey: Hashable {
    let categoryExternalId: String
    let subcategoryExternalId: String
}
