import Foundation
import OSLog

/// Pipeline local de classificação pré-commit.
///
/// O GranaApp pode chamar o executável local GranaAI via contrato JSON. Quando
/// o executável não está configurado ou retorna algo não validável contra a
/// taxonomia carregada, a transação entra em "Não Classificado" para revisão
/// manual antes do commit final.
final class CategorizationService: Sendable {
    struct DraftClassificationResult {
        let suggestions: [CategorizationSuggestion]
    }

    private let categories: any CategoryCatalogRepositoryProtocol
    private let granaAI: (any GranaAIClassificationClientProtocol)?

    init(
        categories: any CategoryCatalogRepositoryProtocol,
        granaAI: (any GranaAIClassificationClientProtocol)? = nil
    ) {
        self.categories = categories
        self.granaAI = granaAI
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

        let fallbackSuggestions = drafts.map { draft in
            buildSuggestion(
                draft: draft,
                categoryId: fallbackId,
                subcategoryId: nil,
                source: .fallback
            )
        }

        guard let granaAI else {
            progress?(.finished(total: drafts.count, fallback: drafts.count))
            return DraftClassificationResult(suggestions: fallbackSuggestions)
        }

        do {
            let taxonomy = GranaAITaxonomyMapping(categories: allCategories)
            let response = try await granaAI.classify(
                GranaAIClassificationRequest(
                    version: GranaAIContract.version,
                    transactions: drafts.map { draft in
                        GranaAIClassificationRequest.Transaction(
                            id: draft.id.uuidString,
                            description: draft.description,
                            amountInMinorUnits: Converters.decimalToCents(draft.signedAmount),
                            currencyCode: "BRL"
                        )
                    },
                    taxonomy: taxonomy.requestTaxonomy,
                    context: .init(locale: "pt-BR")
                )
            )
            let suggestions = buildSuggestions(
                drafts: drafts,
                response: response,
                taxonomy: taxonomy,
                fallbackSuggestions: fallbackSuggestions
            )
            let fallbackCount = suggestions.filter { $0.source == .fallback }.count
            progress?(.finished(total: drafts.count, fallback: fallbackCount))
            return DraftClassificationResult(suggestions: suggestions)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            log.ai.error("GranaAI classification failed; using local fallback: \(error.localizedDescription)")
            progress?(.finished(total: drafts.count, fallback: drafts.count))
            return DraftClassificationResult(suggestions: fallbackSuggestions)
        }
    }

    private func buildSuggestions(
        drafts: [TransactionDraft],
        response: GranaAIClassificationResponse,
        taxonomy: GranaAITaxonomyMapping,
        fallbackSuggestions: [CategorizationSuggestion]
    ) -> [CategorizationSuggestion] {
        var resultsByTransactionId: [String: GranaAIClassificationResponse.Result] = [:]
        for result in response.results {
            resultsByTransactionId[result.transactionId] = result
        }

        return drafts.enumerated().map { index, draft in
            guard let result = resultsByTransactionId[draft.id.uuidString] else {
                return fallbackSuggestions[index]
            }

            guard case let .classified(categoryId, subcategoryId) = result.outcome,
                  let selection = taxonomy.resolve(categoryId: categoryId, subcategoryId: subcategoryId)
            else {
                return fallbackSuggestions[index]
            }

            return buildSuggestion(
                draft: draft,
                categoryId: selection.categoryId,
                subcategoryId: selection.subcategoryId,
                source: .granaAI
            )
        }
    }

    private func buildSuggestion(
        draft: TransactionDraft,
        categoryId: UUID,
        subcategoryId: UUID?,
        source: CategorizationSuggestion.Source
    ) -> CategorizationSuggestion {
        let normalizedDescription = DescriptionNormalizer.normalize(draft.description)
        return CategorizationSuggestion(
            id: UUID(),
            transactionId: draft.id,
            descriptionHash: DescriptionNormalizer.hashNormalized(normalizedDescription),
            normalizedDescription: normalizedDescription,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            source: source,
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
