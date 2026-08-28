import ComposableArchitecture
import Foundation

@Reducer
struct StatementListFeature {
    @ObservableState
    struct State: Equatable {
        let statementId: UUID
        var rows: [StatementTransactionRow] = []
        var isLoading = false
        var hasLoaded = false

        var tableRows: [StatementTransactionTableRow] {
            rows.map(StatementTransactionTableRow.init(source:))
        }
    }

    enum Action: Equatable {
        case task
        case refresh
        case snapshotLoaded(TaskResult<StatementTransactionsSnapshot>)
    }

    @Dependency(\.creditCardsClient) private var creditCardsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.hasLoaded else { return .none }
                return load(&state)

            case .refresh:
                return load(&state)

            case let .snapshotLoaded(.success(snapshot)):
                state.rows = snapshot.rows
                state.isLoading = false
                state.hasLoaded = true
                return .none

            case let .snapshotLoaded(.failure(error)):
                state.rows = []
                state.isLoading = false
                state.hasLoaded = true
                return .run { _ in
                    await noticeClient.report(error, nil)
                }
            }
        }
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.isLoading = true
        return .run { [statementId = state.statementId] send in
            await send(.snapshotLoaded(TaskResult {
                try await creditCardsClient.loadStatementTransactions(statementId)
            }))
        }
    }
}
