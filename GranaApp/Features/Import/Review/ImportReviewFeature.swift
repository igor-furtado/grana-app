import ComposableArchitecture
import Foundation

@Reducer
struct ImportReviewFeature {
    @ObservableState
    struct State: Equatable {
        var plan: PendingImportPlan
        var suggestions: [CategorizationSuggestion]
        var categories: [Category]
        var accounts: [Account]
        var institutions: [Institution]

        init(
            plan: PendingImportPlan,
            suggestions: [CategorizationSuggestion] = [],
            categories: [Category] = [],
            accounts: [Account] = [],
            institutions: [Institution] = []
        ) {
            self.plan = plan
            self.suggestions = suggestions
            self.categories = categories
            self.accounts = accounts
            self.institutions = institutions
        }

        var rootCategories: [Category] {
            categories.filter { $0.parentId == nil }
        }

        func subcategories(of parentId: UUID) -> [Category] {
            categories.filter { $0.parentId == parentId }
        }

        func category(for id: UUID) -> Category? {
            categories.first { $0.id == id }
        }

        func institutionKind(forAccountId accountId: UUID) -> InstitutionKind? {
            guard let account = accounts.first(where: { $0.id == accountId }),
                  let institutionId = account.institutionId,
                  let institution = institutions.first(where: { $0.id == institutionId })
            else { return nil }
            return institution.kind
        }

        func resolvedCategory(forTransactionId id: UUID) -> (categoryId: UUID, subcategoryId: UUID?)? {
            guard let suggestion = suggestions.first(where: { $0.transactionId == id }) else { return nil }
            return (suggestion.categoryId, suggestion.subcategoryId)
        }

        var reviewedRows: [ReviewedImportRow] {
            plan.drafts.map { draft in
                let resolved = resolvedCategory(forTransactionId: draft.id)
                return ReviewedImportRow(
                    draft: draft,
                    categoryId: resolved?.categoryId,
                    subcategoryId: resolved?.subcategoryId
                )
            }
        }
    }

    enum Action: Equatable {
        case confirm(Int)
        case confirmAll
        case applyCorrection(index: Int, categoryId: UUID, subcategoryId: UUID?)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .confirm(index):
                guard state.suggestions.indices.contains(index) else { return .none }
                state.suggestions[index].isReviewed = true
                return .none

            case .confirmAll:
                for index in state.suggestions.indices where !state.suggestions[index].isReviewed {
                    state.suggestions[index].isReviewed = true
                }
                return .none

            case let .applyCorrection(index, categoryId, subcategoryId):
                guard state.suggestions.indices.contains(index) else { return .none }
                let hash = state.suggestions[index].descriptionHash
                for suggestionIndex in state.suggestions.indices {
                    guard state.suggestions[suggestionIndex].descriptionHash == hash else { continue }
                    state.suggestions[suggestionIndex].categoryId = categoryId
                    state.suggestions[suggestionIndex].subcategoryId = subcategoryId
                    state.suggestions[suggestionIndex].isReviewed = true
                }
                return .none
            }
        }
    }
}
