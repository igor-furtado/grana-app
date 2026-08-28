import ComposableArchitecture
import Foundation

@Reducer
struct SupportedInstitutionsFeature {
    @ObservableState
    struct State: Equatable {
        var institutions: [Institution] = []
        var isLoading = false
        var hasLoaded = false
        var loadErrorMessage: String?

        var subtitle: String {
            "\(institutions.count) instituições no catálogo global"
        }
    }

    enum Action: Equatable {
        case task
        case refresh
        case snapshotLoaded(TaskResult<[Institution]>)
    }

    @Dependency(\.supportedInstitutionsClient) private var supportedInstitutionsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.hasLoaded else { return .none }
                return load(&state)

            case .refresh:
                return load(&state)

            case let .snapshotLoaded(.success(institutions)):
                state.institutions = institutions
                state.isLoading = false
                state.hasLoaded = true
                state.loadErrorMessage = nil
                return .none

            case let .snapshotLoaded(.failure(error)):
                state.institutions = []
                state.isLoading = false
                state.hasLoaded = true
                state.loadErrorMessage = error.localizedDescription
                return .run { _ in
                    await noticeClient.report(error, nil)
                }
            }
        }
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.isLoading = true
        return .run { send in
            await send(.snapshotLoaded(TaskResult { try await supportedInstitutionsClient.load() }))
        }
    }
}
