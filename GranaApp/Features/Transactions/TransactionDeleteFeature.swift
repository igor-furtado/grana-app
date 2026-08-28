import ComposableArchitecture
import Foundation

@Reducer
struct TransactionDeleteFeature {
    @ObservableState
    struct State: Equatable {
        let transaction: Transaction
        let impactMessage: String
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

    @Dependency(\.transactionsClient) private var transactionsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .cancelButtonTapped:
                return .send(.delegate(.cancel))

            case .confirmButtonTapped:
                state.isSaving = true
                state.saveError = nil
                return .run { [transaction = state.transaction] send in
                    do {
                        try await transactionsClient.delete(transaction.id)
                        await noticeClient.success("Transação apagada", nil)
                        await send(.saveSucceeded)
                    } catch {
                        await noticeClient.report(error, "Falha ao apagar transação")
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
