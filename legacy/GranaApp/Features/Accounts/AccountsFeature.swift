import ComposableArchitecture
import Foundation

@Reducer
struct AccountsFeature {
    @Reducer
    enum Destination {
        case form(AccountFormFeature)
        case archive(AccountArchiveFeature)
        case delete(AccountDeleteFeature)
    }

    @ObservableState
    struct State: Equatable {
        var list = AccountListFeature.State()
        var isLoading = false
        var hasLoaded = false

        @Presents var destination: Destination.State?

        func account(for id: UUID) -> AccountListItem? {
            list.items.first { $0.id == id }
        }
    }

    enum Action: Equatable {
        case task
        case refresh
        case snapshotLoaded(TaskResult<AccountsSnapshot>)
        case list(AccountListFeature.Action)
        case destination(PresentationAction<Destination.Action>)
    }

    @Dependency(\.accountsClient) private var accountsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Scope(state: \.list, action: \.list) {
            AccountListFeature()
        }

        Reduce { state, action in
            switch action {
            case .task:
                guard !state.hasLoaded else { return .none }
                return load(&state)

            case .refresh:
                return load(&state)

            case let .snapshotLoaded(.success(snapshot)):
                state.list.apply(snapshot)
                state.isLoading = false
                state.hasLoaded = true
                return .none

            case let .snapshotLoaded(.failure(error)):
                state.list.items = []
                state.list.institutions = []
                state.list.selectedAccountId = nil
                state.isLoading = false
                state.hasLoaded = true
                return .run { _ in
                    await noticeClient.report(error, nil)
                }

            case .list(.binding(\.showArchived)):
                let previousSelection = state.list.selectedAccountId
                let visibleIds = Set(state.list.visibleItems.map(\.id))
                if let previousSelection, visibleIds.contains(previousSelection) {
                    return .none
                }
                state.list.selectedAccountId = state.list.visibleItems.first?.id
                return .none

            case .list(.binding):
                state.list.reconcileSelection()
                return .none

            case .list(.delegate(.createRequested)):
                state.destination = .form(AccountFormFeature.State(institutions: state.list.institutions))
                return .none

            case let .list(.delegate(.accountSelected(id))):
                state.list.selectedAccountId = id
                return .none

            case let .list(.delegate(.editRequested(id))):
                guard let account = state.account(for: id) else { return .none }
                state.destination = .form(
                    AccountFormFeature.State(
                        existingAccount: account,
                        institutions: state.list.institutions
                    )
                )
                return .none

            case let .list(.delegate(.archiveRequested(id))):
                guard let account = state.account(for: id) else { return .none }
                state.destination = .archive(AccountArchiveFeature.State(account: account))
                return .none

            case let .list(.delegate(.deleteRequested(id))):
                guard let account = state.account(for: id) else { return .none }
                state.destination = .delete(AccountDeleteFeature.State(account: account))
                return .none

            case .list:
                return .none

            case .destination(.presented(.form(.delegate(.cancel)))),
                 .destination(.presented(.archive(.delegate(.cancel)))),
                 .destination(.presented(.delete(.delegate(.cancel)))):
                state.destination = nil
                return .none

            case .destination(.presented(.form(.delegate(.saved)))),
                 .destination(.presented(.archive(.delegate(.confirmed)))),
                 .destination(.presented(.delete(.delegate(.confirmed)))):
                state.destination = nil
                return .send(.refresh)

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.isLoading = true
        return .run { send in
            await send(.snapshotLoaded(TaskResult { try await accountsClient.loadList() }))
        }
    }
}

extension AccountsFeature.Destination.State: Equatable {}
extension AccountsFeature.Destination.Action: Equatable {}
