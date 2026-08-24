import Foundation

/// Pipeline local mínimo de classificação pré-commit.
///
/// Nesta etapa do produto o GranaApp não chama IA remota nem persiste memória
/// de categorização. Toda transação importada entra como "Não Classificado" e
/// segue para revisão manual antes do commit final.
final class CategorizationService: Sendable {
    struct DraftClassificationResult {
        let suggestions: [CategorizationSuggestion]
    }

    private let categories: any CategoryCatalogRepositoryProtocol

    init(categories: any CategoryCatalogRepositoryProtocol) {
        self.categories = categories
    }

    typealias ProgressHandler = @Sendable (Progress) -> Void

    enum Progress {
        case started(total: Int)
        case finished(total: Int, fallback: Int)
        case failed(error: Error)
    }

    func classifyDrafts(
        _ drafts: [TransactionDraft],
        progress: ProgressHandler? = nil
    ) async throws -> DraftClassificationResult {
        guard !drafts.isEmpty else {
            progress?(.finished(total: 0, fallback: 0))
            return DraftClassificationResult(suggestions: [])
        }

        progress?(.started(total: drafts.count))

        let allCategories = try await categories.load()
        guard let fallbackId = allCategories.rootCategory(slug: "nao-classificado")?.id else {
            throw CategorizationError.categoryNotFound(slug: "nao-classificado")
        }

        let suggestions = drafts.map { draft in
            buildFallbackSuggestion(
                draft: draft,
                fallbackCategoryId: fallbackId
            )
        }

        progress?(.finished(total: drafts.count, fallback: drafts.count))
        return DraftClassificationResult(suggestions: suggestions)
    }

    private func buildFallbackSuggestion(
        draft: TransactionDraft,
        fallbackCategoryId: UUID
    ) -> CategorizationSuggestion {
        let normalizedDescription = DescriptionNormalizer.normalize(draft.description)
        return CategorizationSuggestion(
            id: UUID(),
            transactionId: draft.id,
            descriptionHash: DescriptionNormalizer.hashNormalized(normalizedDescription),
            normalizedDescription: normalizedDescription,
            categoryId: fallbackCategoryId,
            subcategoryId: nil,
            source: .fallback,
            originalCategoryId: nil,
            originalSubcategoryId: nil,
            originalCategorySlug: nil,
            originalSubcategoryName: nil,
            transactionDescription: draft.description,
            transactionAmount: abs(draft.signedAmount),
            transactionOccurredAt: draft.occurredAt,
            transactionAccountId: draft.accountId,
            transactionNotes: draft.notes,
            transactionDestinationAccountId: draft.destinationAccountId,
            transactionRefundOfTransactionId: draft.refundOfTransactionId,
            isReviewed: false
        )
    }
}

enum CategorizationError: LocalizedError {
    case categoryNotFound(slug: String)

    var errorDescription: String? {
        switch self {
        case let .categoryNotFound(slug):
            return "Categoria com slug '\(slug)' não encontrada no catálogo carregado."
        }
    }
}
