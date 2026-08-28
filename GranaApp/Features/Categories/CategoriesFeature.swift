import ComposableArchitecture
import Foundation

struct CategoriesClient {
    var loadCategories: @Sendable () async throws -> [Category]
}

extension CategoriesClient {
    static func live(container: AppContainer) -> CategoriesClient {
        CategoriesClient(
            loadCategories: {
                try await container.categoryCatalog.load()
            }
        )
    }
}

extension CategoriesClient: DependencyKey {
    static let liveValue = CategoriesClient(
        loadCategories: { [] }
    )

    static let testValue = CategoriesClient(
        loadCategories: unimplemented("CategoriesClient.loadCategories")
    )
}

extension DependencyValues {
    var categoriesClient: CategoriesClient {
        get { self[CategoriesClient.self] }
        set { self[CategoriesClient.self] = newValue }
    }
}

@Reducer
struct CategoriesFeature {
    @ObservableState
    struct State: Equatable {
        var categories: [Category] = []
        var isLoading = false
        var hasLoaded = false
        var selectedId: UUID?
        var loadErrorMessage: String?

        var rootCategories: [Category] {
            categories.filter { $0.parentId == nil }
        }

        var sortedRootCategories: [Category] {
            rootCategories.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }

        mutating func applyLoadedCategories(_ categories: [Category]) {
            self.categories = categories
            loadErrorMessage = nil
            reconcileSelection()
        }

        mutating func reconcileSelection() {
            let visibleRootIds = Set(rootCategories.map(\.id))
            if let selectedId, visibleRootIds.contains(selectedId) {
                return
            }
            selectedId = sortedRootCategories.first?.id
        }
    }

    enum Action: Equatable {
        case task
        case refresh
        case categoriesLoaded([Category])
        case loadFailed(String)
        case select(UUID)
    }

    @Dependency(\.categoriesClient) private var categoriesClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.hasLoaded else { return .none }
                return load(&state)

            case .refresh:
                return load(&state)

            case let .categoriesLoaded(categories):
                state.applyLoadedCategories(categories)
                state.isLoading = false
                state.hasLoaded = true
                return .none

            case let .loadFailed(message):
                state.isLoading = false
                state.loadErrorMessage = message
                return .none

            case let .select(id):
                state.selectedId = id
                return .none
            }
        }
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.isLoading = true
        return .run { send in
            do {
                let categories = try await categoriesClient.loadCategories()
                await send(.categoriesLoaded(categories))
            } catch {
                await noticeClient.report(error, nil)
                await send(.loadFailed(error.localizedDescription))
            }
        }
    }
}
