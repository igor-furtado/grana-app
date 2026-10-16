import ComposableArchitecture
import Foundation

@Reducer
struct AccountDeleteFeature {
    @ObservableState
    struct State: Equatable {
        let account: AccountListItem
        var isSaving = false
        var saveError: String?
    }

    enum Action: Equatable {
        case cancelButtonTapped
        case confirmButtonTapped
        case saveSucceeded
        case saveFailed(String)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case cancel
        case confirmed
    }

    @Dependency(\.accountsClient) private var accountsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .cancelButtonTapped:
                return .send(.delegate(.cancel))

            case .confirmButtonTapped:
                state.isSaving = true
                state.saveError = nil
                return .run { [account = state.account] send in
                    do {
                        try await accountsClient.delete(account.id)
                        await send(.saveSucceeded)
                    } catch {
                        await noticeClient.report(error, "Falha ao apagar conta")
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case .saveSucceeded:
                state.isSaving = false
                return .send(.delegate(.confirmed))

            case let .saveFailed(message):
                state.isSaving = false
                state.saveError = message
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
