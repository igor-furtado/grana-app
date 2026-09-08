import ComposableArchitecture
import Foundation

@Reducer
struct ImportReviewFeature {
    @ObservableState
    struct State: Equatable {
        var plan: PendingImportPlan
        var categorization: ImportCategorizationFeature.State

        init(
            plan: PendingImportPlan,
            categorization: ImportCategorizationFeature.State = ImportCategorizationFeature.State()
        ) {
            self.plan = plan
            self.categorization = categorization
        }

        var reviewedRows: [ReviewedImportRow] {
            plan.drafts.map { draft in
                let resolved = categorization.resolvedCategory(forTransactionId: draft.id)
                return ReviewedImportRow(
                    draft: draft,
                    categoryId: resolved?.categoryId,
                    subcategoryId: resolved?.subcategoryId
                )
            }
        }
    }

    enum Action: Equatable {
        case start
        case categorization(ImportCategorizationFeature.Action)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case ready
        case failed(String)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .start:
                return .send(.categorization(.start(state.plan.drafts)))

            case .categorization(.delegate(.ready)):
                return .send(.delegate(.ready))

            case let .categorization(.delegate(.failed(message))):
                return .send(.delegate(.failed(message)))

            case .categorization, .delegate:
                return .none
            }
        }
        Scope(state: \.categorization, action: \.categorization) {
            ImportCategorizationFeature()
        }
    }
}
