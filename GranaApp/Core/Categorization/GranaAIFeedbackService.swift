import Foundation

/// Monta e envia ao GranaAI as classificações finais confirmadas pelo usuário.
///
/// A memória de classificações vive exclusivamente no GranaAI. O app apenas
/// transporta o feedback validado contra a taxonomia atual e não persiste
/// histórico de revisões confirmadas.
final class GranaAIFeedbackService: Sendable {
    private let granaAI: (any GranaAIClassificationClientProtocol)?

    init(granaAI: (any GranaAIClassificationClientProtocol)? = nil) {
        self.granaAI = granaAI
    }

    func learnConfirmedClassifications(
        suggestions: [CategorizationSuggestion],
        categories: [Category]
    ) async throws {
        guard let request = try Self.buildLearningRequest(
            suggestions: suggestions,
            categories: categories
        ) else {
            return
        }

        guard let granaAI else {
            throw GranaAIFeedbackServiceError.unavailable
        }

        try await granaAI.learn(request)
    }

    func learnConfirmedClassifications(request: GranaAIClassificationLearningRequest) async throws {
        guard let granaAI else {
            throw GranaAIFeedbackServiceError.unavailable
        }

        try await granaAI.learn(request)
    }

    nonisolated static func buildLearningRequest(
        suggestions: [CategorizationSuggestion],
        categories: [Category]
    ) throws -> GranaAIClassificationLearningRequest? {
        let taxonomy = GranaAITaxonomyMapping(categories: categories)
        guard let fallbackCategoryId = categories.rootCategory(slug: "nao-classificado")?.id else {
            throw CategorizationError.categoryNotFound(slug: "nao-classificado")
        }

        let confirmedClassifications: [GranaAIClassificationLearningRequest.ConfirmedClassification] =
            try suggestions.compactMap { suggestion in
                guard suggestion.categoryId != fallbackCategoryId else {
                    return nil
                }

                guard let selection = taxonomy.externalSelection(
                    categoryId: suggestion.categoryId,
                    subcategoryId: suggestion.subcategoryId
                ) else {
                    throw GranaAIFeedbackServiceError.invalidSelection(
                        categoryId: suggestion.categoryId,
                        subcategoryId: suggestion.subcategoryId
                    )
                }

                return GranaAIClassificationLearningRequest.ConfirmedClassification(
                    description: suggestion.transactionDescription,
                    categoryId: selection.categoryId,
                    subcategoryId: selection.subcategoryId
                )
            }

        guard !confirmedClassifications.isEmpty else {
            return nil
        }

        return GranaAIClassificationLearningRequest(
            version: GranaAIContract.version,
            taxonomy: taxonomy.requestTaxonomy,
            confirmedClassifications: confirmedClassifications
        )
    }
}

enum GranaAIFeedbackServiceError: LocalizedError, Equatable {
    case unavailable
    case invalidSelection(categoryId: UUID, subcategoryId: UUID?)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "O GranaAI local não está disponível para aprender as classificações confirmadas."
        case let .invalidSelection(categoryId, subcategoryId):
            return "Não foi possível converter a classificação confirmada para a taxonomia do GranaAI. categoryId=\(categoryId.uuidString) subcategoryId=\(subcategoryId?.uuidString ?? "nil")"
        }
    }
}
