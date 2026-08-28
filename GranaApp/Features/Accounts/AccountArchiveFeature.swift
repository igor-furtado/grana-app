import ComposableArchitecture
import Foundation

@Reducer
struct AccountArchiveFeature {
    @ObservableState
    struct State: Equatable {
        let account: AccountListItem
        var isSaving = false
        var saveError: String?

        var targetArchived: Bool {
            !account.account.archived
        }

        var title: String {
            targetArchived ? "Arquivar conta" : "Desarquivar conta"
        }

        var confirmTitle: String {
            targetArchived ? "Arquivar" : "Desarquivar"
        }

        var message: String {
            targetArchived
                ? "A conta sai dos pickers e resumos, mas mantém histórico e importações vinculadas."
                : "A conta volta a aparecer na lista principal e pode receber novas transações e importações."
        }
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
                return .run { [account = state.account, targetArchived = state.targetArchived] send in
                    do {
                        try await accountsClient.setArchived(account.id, targetArchived)
                        await send(.saveSucceeded)
                    } catch {
                        await noticeClient.report(error, "Falha ao atualizar conta")
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
