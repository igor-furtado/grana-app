import ComposableArchitecture
import Foundation

struct ImportCategorizationContext: Equatable {
    var categories: [Category]
    var accounts: [Account]
    var institutions: [Institution]
}

struct ImportCategorizationClient {
    var loadContext: @Sendable () async throws -> ImportCategorizationContext
    var classifyDrafts: @Sendable (_ drafts: [TransactionDraft]) async throws -> [CategorizationSuggestion]
}

extension ImportCategorizationClient {
    static func live(container: AppContainer) -> ImportCategorizationClient {
        ImportCategorizationClient(
            loadContext: {
                async let categoriesTask = container.categoryCatalog.load()
                async let accountsTask = container.remoteAccounts.load()
                async let institutionsTask = container.institutionCatalog.load()
                let (categories, accountSnapshot, institutions) = try await (
                    categoriesTask,
                    accountsTask,
                    institutionsTask
                )
                return ImportCategorizationContext(
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

extension ImportCategorizationClient: DependencyKey {
    static let liveValue = ImportCategorizationClient(
        loadContext: { ImportCategorizationContext(categories: [], accounts: [], institutions: []) },
        classifyDrafts: { _ in [] }
    )

    static let testValue = ImportCategorizationClient(
        loadContext: unimplemented("ImportCategorizationClient.loadContext"),
        classifyDrafts: unimplemented("ImportCategorizationClient.classifyDrafts")
    )
}

extension DependencyValues {
    var importCategorizationClient: ImportCategorizationClient {
        get { self[ImportCategorizationClient.self] }
        set { self[ImportCategorizationClient.self] = newValue }
    }
}

@Reducer
struct ImportCategorizationFeature {
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
    }

    enum Action: Equatable {
        case start([TransactionDraft])
        case contextLoaded(TaskResult<ImportCategorizationContext>)
        case suggestionsLoaded(TaskResult<[CategorizationSuggestion]>)
        case cancel
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case ready
        case failed(String)
    }

    @Dependency(\.importCategorizationClient) private var importCategorizationClient
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
                                TaskResult { try await importCategorizationClient.loadContext() }
                            )
                        )
                    },
                    .run { send in
                        await send(
                            .suggestionsLoaded(
                                TaskResult {
                                    try await importCategorizationClient.classifyDrafts(drafts)
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
