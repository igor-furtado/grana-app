import Foundation

struct CategorizationPendingCacheEntry: Hashable, Sendable {
    let descriptionHash: String
    let normalizedDescription: String
    let categorySlug: String
    let subcategoryName: String?
    let confidence: Double
    let model: String
    let createdAt: Date
    let updatedAt: Date
}

struct CategorizationPendingCorrection: Hashable, Sendable {
    let descriptionHash: String
    let normalizedDescription: String
    let originalCategorySlug: String?
    let originalSubcategoryName: String?
    let correctedCategorySlug: String
    let correctedSubcategoryName: String?
    let transactionId: UUID
    let createdAt: Date
}
