import ComposableArchitecture
import Foundation

struct CategorizationContext: Equatable {
    var categories: [Category]
    var accounts: [Account]
    var institutions: [Institution]
}

struct CategorizationClient {
    var loadContext: @Sendable () async throws -> CategorizationContext
    var classifyDrafts: @Sendable (_ drafts: [TransactionDraft]) async throws -> [CategorizationSuggestion]
}

extension CategorizationClient {
    static func live(container: AppContainer) -> CategorizationClient {
        CategorizationClient(
            loadContext: {
                async let categoriesTask = container.categoryCatalog.load()
                async let accountsTask = container.remoteAccounts.load()
                async let institutionsTask = container.institutionCatalog.load()
                let (categories, accountSnapshot, institutions) = try await (
                    categoriesTask,
                    accountsTask,
                    institutionsTask
                )
                return CategorizationContext(
                    categories: categories,
                    accounts: accountSnapshot.accounts,
                    institutions: institutions
                )
            },
            classifyDrafts: { drafts in
                let result = try await container.categorization.classifyDrafts(drafts)
                return result.suggestions
            }
        )
    }
}

extension CategorizationClient: DependencyKey {
    static let liveValue = CategorizationClient(
        loadContext: { CategorizationContext(categories: [], accounts: [], institutions: []) },
        classifyDrafts: { _ in [] }
    )

    static let testValue = CategorizationClient(
        loadContext: unimplemented("CategorizationClient.loadContext"),
        classifyDrafts: unimplemented("CategorizationClient.classifyDrafts")
    )
}

extension DependencyValues {
    var categorizationClient: CategorizationClient {
        get { self[CategorizationClient.self] }
        set { self[CategorizationClient.self] = newValue }
    }
}

@Reducer
struct CategorizationFeature {
    enum Status: Equatable {
        case idle
        case classifying(processed: Int, total: Int, message: String)
        case ready(total: Int, fallback: Int)
        case failed(message: String)
    }

    @ObservableState
    struct State: Equatable {
        var status: Status = .idle
        var suggestions: [CategorizationSuggestion] = []
        var categories: [Category] = []
        var accounts: [Account] = []
        var institutions: [Institution] = []

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
    }

    enum Action: Equatable {
        case start([TransactionDraft])
        case contextLoaded(TaskResult<CategorizationContext>)
        case suggestionsLoaded(TaskResult<[CategorizationSuggestion]>)
        case confirm(Int)
        case confirmAll
        case applyCorrection(index: Int, categoryId: UUID, subcategoryId: UUID?)
        case cancel
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case ready
        case failed(String)
    }

    @Dependency(\.categorizationClient) private var categorizationClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .start(drafts):
                state.status = .classifying(
                    processed: 0,
                    total: drafts.count,
                    message: "Preparando classificação…"
                )
                state.suggestions = []
                return .merge(
                    .run { send in
                        await send(
                            .contextLoaded(
                                TaskResult { try await categorizationClient.loadContext() }
                            )
                        )
                    },
                    .run { send in
                        await send(
                            .suggestionsLoaded(
                                TaskResult {
                                    try await categorizationClient.classifyDrafts(drafts)
                                }
                            )
                        )
                    }
                    .cancellable(id: "categorization.classify", cancelInFlight: true)
                )

            case let .contextLoaded(.success(context)):
                state.categories = context.categories
                state.accounts = context.accounts
                state.institutions = context.institutions
                return .none

            case let .contextLoaded(.failure(error)):
                state.status = .failed(message: error.localizedDescription)
                return .merge(
                    .run { _ in
                        await noticeClient.report(error, "Falha ao classificar")
                    },
                    .send(.delegate(.failed(error.localizedDescription)))
                )

            case let .suggestionsLoaded(.success(suggestions)):
                state.suggestions = suggestions
                let fallback = suggestions.filter { suggestion in
                    state.category(for: suggestion.categoryId)?.slug == "nao-classificado"
                }.count
                state.status = .ready(total: suggestions.count, fallback: fallback)
                return .send(.delegate(.ready))

            case let .suggestionsLoaded(.failure(error)):
                state.status = .failed(message: error.localizedDescription)
                return .merge(
                    .run { _ in
                        await noticeClient.report(error, "Falha ao classificar")
                    },
                    .send(.delegate(.failed(error.localizedDescription)))
                )

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
                for suggestionIndex in state.suggestions.indices
                    where state.suggestions[suggestionIndex].descriptionHash == hash
                {
                    state.suggestions[suggestionIndex].categoryId = categoryId
                    state.suggestions[suggestionIndex].subcategoryId = subcategoryId
                    state.suggestions[suggestionIndex].isReviewed = true
                }
                return .none

            case .cancel:
                state.status = .idle
                state.suggestions = []
                return .cancel(id: "categorization.classify")

            case .delegate:
                return .none
            }
        }
    }
}
