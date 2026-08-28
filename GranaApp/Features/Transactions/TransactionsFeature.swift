import ComposableArchitecture
import Foundation

@Reducer
struct TransactionsFeature {
    @Reducer
    enum Destination {
        case editForm(TransactionFormFeature)
        case delete(TransactionDeleteFeature)
    }

    enum FormPresentation: Equatable {
        case new
        case edit(Transaction)
    }

    @ObservableState
    struct State: Equatable {
        var list = TransactionListFeature.State()
        var hasLoaded = false
        var pendingFormPresentation: FormPresentation?

        @Presents var destination: Destination.State?

        func formState(existing: Transaction? = nil) -> TransactionFormFeature.State {
            TransactionFormFeature.State(
                existing: existing,
                transactions: list.transactions,
                accounts: list.accounts,
                institutions: list.institutions,
                bankDetails: list.bankDetails,
                creditCards: list.creditCards,
                categories: list.categories,
                statements: list.statements,
                statementPayments: list.statementPayments
            )
        }

        func deleteState(for transaction: Transaction) -> TransactionDeleteFeature.State {
            TransactionDeleteFeature.State(
                transaction: transaction,
                impactMessage: list.deleteImpactMessage(for: transaction)
            )
        }

        mutating func requestFormPresentation(_ presentation: FormPresentation) {
            guard case var .editForm(formState) = destination else {
                presentForm(presentation)
                return
            }

            guard !formState.isSaving else { return }

            if formState.hasUnsavedChanges {
                pendingFormPresentation = presentation
                formState.showsDiscardConfirmation = true
                destination = .editForm(formState)
            } else {
                presentForm(presentation)
            }
        }

        mutating func presentForm(_ presentation: FormPresentation) {
            pendingFormPresentation = nil
            switch presentation {
            case .new:
                destination = .editForm(formState())
            case let .edit(transaction):
                destination = .editForm(formState(existing: transaction))
            }
        }
    }

    enum Action {
        case task
        case refresh
        case snapshotLoaded(TransactionsSnapshot)
        case loadFailed
        case postDeleteRefreshCompleted(TransactionsSnapshot)
        case postDeleteRefreshFailed
        case list(TransactionListFeature.Action)
        case destination(PresentationAction<Destination.Action>)
    }

    @Dependency(\.transactionsClient) private var transactionsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Scope(state: \.list, action: \.list) {
            TransactionListFeature()
        }

        Reduce { state, action in
            switch action {
            case .task:
                guard !state.hasLoaded else { return .none }
                return load(&state)

            case .refresh:
                return load(&state)

            case let .snapshotLoaded(snapshot):
                state.list.apply(snapshot)
                state.list.isLoading = false
                state.hasLoaded = true
                return .none

            case .loadFailed:
                state.list.clearLoadedData()
                state.list.isLoading = false
                state.hasLoaded = true
                return .none

            case let .postDeleteRefreshCompleted(snapshot):
                state.list.apply(snapshot)
                state.list.isLoading = false
                state.hasLoaded = true
                return .none

            case .postDeleteRefreshFailed:
                state.list.isLoading = false
                state.hasLoaded = true
                return .none

            case .list(.binding):
                return .none

            case .list(.delegate(.createRequested)):
                state.requestFormPresentation(.new)
                return .none

            case let .list(.delegate(.editRequested(transaction))):
                state.requestFormPresentation(.edit(transaction))
                return .none

            case let .list(.delegate(.deleteRequested(transaction))):
                state.destination = .delete(state.deleteState(for: transaction))
                return .none

            case .list:
                return .none

            case .destination(.presented(.editForm(.delegate(.cancel)))),
                 .destination(.presented(.delete(.delegate(.cancel)))):
                state.pendingFormPresentation = nil
                state.destination = nil
                return .none

            case .destination(.presented(.editForm(.delegate(.discarded)))):
                if let pendingFormPresentation = state.pendingFormPresentation {
                    state.presentForm(pendingFormPresentation)
                } else {
                    state.destination = nil
                }
                return .none

            case .destination(.presented(.editForm(.delegate(.saved)))):
                state.destination = nil
                return .send(.refresh)

            case .destination(.presented(.delete(.delegate(.confirmed)))):
                state.destination = nil
                state.list.isLoading = true
                return .run { send in
                    do {
                        let snapshot = try await transactionsClient.loadSnapshot()
                        await send(.postDeleteRefreshCompleted(snapshot))
                    } catch {
                        await noticeClient.report(error, "Transação apagada, mas falha ao atualizar lista")
                        await send(.postDeleteRefreshFailed)
                    }
                }

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.list.isLoading = true
        return .run { send in
            do {
                let snapshot = try await transactionsClient.loadSnapshot()
                await send(.snapshotLoaded(snapshot))
            } catch {
                await noticeClient.report(error, nil)
                await send(.loadFailed)
            }
        }
    }
}

extension TransactionsFeature.Destination.State: Equatable {}
extension TransactionsFeature.Destination.Action: Equatable {}

extension TransactionsFeature.Action: Equatable {
    static func == (lhs: TransactionsFeature.Action, rhs: TransactionsFeature.Action) -> Bool {
        switch (lhs, rhs) {
        case (.task, .task),
             (.refresh, .refresh),
             (.loadFailed, .loadFailed),
             (.postDeleteRefreshFailed, .postDeleteRefreshFailed),
             (.snapshotLoaded, .snapshotLoaded),
             (.postDeleteRefreshCompleted, .postDeleteRefreshCompleted):
            true
        case let (.list(lhsAction), .list(rhsAction)):
            lhsAction == rhsAction
        case let (.destination(lhsAction), .destination(rhsAction)):
            lhsAction == rhsAction
        default:
            false
        }
    }
}
