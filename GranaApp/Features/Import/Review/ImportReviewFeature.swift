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
        var transferAccountSelections: [UUID: UUID] = [:]

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

        func draft(forTransactionId id: UUID) -> TransactionDraft? {
            plan.drafts.first { $0.id == id }
        }

        func isTransfer(categoryId: UUID?) -> Bool {
            guard let categoryId else { return false }
            return category(for: categoryId)?.kind == .transfer
        }

        func transferCounterpartyRole(forTransactionId id: UUID) -> String {
            guard let draft = draft(forTransactionId: id) else {
                return "conta"
            }
            return draft.signedAmount < 0 ? "Conta de destino" : "Conta de origem"
        }

        var canImport: Bool {
            !suggestions.isEmpty && invalidTransferTransactionIds.isEmpty
        }

        var invalidTransferTransactionIds: Set<UUID> {
            Set(suggestions.compactMap { suggestion in
                guard isTransfer(categoryId: suggestion.categoryId),
                      let draft = draft(forTransactionId: suggestion.transactionId)
                else { return nil }
                guard let selectedAccountId = transferAccountSelections[draft.id],
                      selectedAccountId != draft.accountId,
                      accounts.contains(where: { $0.id == selectedAccountId && !$0.archived })
                else {
                    return draft.id
                }
                return nil
            })
        }

        var reviewedRows: [ReviewedImportRow] {
            plan.drafts.map { draft in
                let resolved = resolvedCategory(forTransactionId: draft.id)
                let transferAccounts = reviewedTransferAccounts(
                    draft: draft,
                    categoryId: resolved?.categoryId
                )
                return ReviewedImportRow(
                    draft: draft,
                    categoryId: resolved?.categoryId,
                    subcategoryId: isTransfer(categoryId: resolved?.categoryId) ? nil : resolved?.subcategoryId,
                    accountId: transferAccounts.accountId,
                    destinationAccountId: transferAccounts.destinationAccountId
                )
            }
        }

        private func reviewedTransferAccounts(
            draft: TransactionDraft,
            categoryId: UUID?
        ) -> (accountId: UUID?, destinationAccountId: UUID?) {
            guard isTransfer(categoryId: categoryId),
                  let relatedAccountId = transferAccountSelections[draft.id],
                  relatedAccountId != draft.accountId
            else {
                return (nil, nil)
            }
            if draft.signedAmount < 0 {
                return (draft.accountId, relatedAccountId)
            }
            return (relatedAccountId, draft.accountId)
        }
    }

    enum Action: Equatable {
        case confirm(Int)
        case confirmAll
        case applyCorrection(index: Int, categoryId: UUID, subcategoryId: UUID?)
        case transferAccountChanged(index: Int, accountId: UUID?)
        case importButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case completed(ReviewedImportCommit)
    }

    @Dependency(\.uuid) private var uuid

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
                let isTransfer = state.isTransfer(categoryId: categoryId)
                for suggestionIndex in state.suggestions.indices {
                    guard state.suggestions[suggestionIndex].descriptionHash == hash else { continue }
                    state.suggestions[suggestionIndex].categoryId = categoryId
                    state.suggestions[suggestionIndex].subcategoryId = isTransfer ? nil : subcategoryId
                    state.suggestions[suggestionIndex].isReviewed = true
                    if !isTransfer {
                        state.transferAccountSelections[state.suggestions[suggestionIndex].transactionId] = nil
                    }
                }
                return .none

            case let .transferAccountChanged(index, accountId):
                guard state.suggestions.indices.contains(index),
                      let draft = state.draft(forTransactionId: state.suggestions[index].transactionId)
                else { return .none }
                if accountId == draft.accountId {
                    state.transferAccountSelections[draft.id] = nil
                } else {
                    state.transferAccountSelections[draft.id] = accountId
                }
                return .none

            case .importButtonTapped:
                guard state.canImport else { return .none }
                return .send(.delegate(.completed(ReviewedImportCommit(
                    idempotencyKey: uuid(),
                    reviewedRows: state.reviewedRows,
                    pendingBatches: state.plan.batches,
                    categories: state.categories,
                    suggestions: state.suggestions
                ))))

            case .delegate:
                return .none
            }
        }
    }
}
