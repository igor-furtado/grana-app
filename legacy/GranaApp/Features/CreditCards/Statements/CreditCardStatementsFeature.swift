import ComposableArchitecture
import Foundation

@Reducer
struct CreditCardStatementsFeature {
    @ObservableState
    struct State: Equatable {
        var card: CreditCardListItem
        var statements: [Statement] = []
        var projections: [StatementWindow] = []
        var selectedStatementId: UUID?
        var statementList: StatementListFeature.State?
        var isLoading = false
        var hasLoaded = false

        @Presents var dateEditor: StatementDateEditorFeature.State?

        var defaultStatementId: UUID? {
            if let open = statements.first(where: {
                $0.status() == .forming || $0.remainingAmount > 0
            }) {
                return open.id
            }
            return statements.last?.id
        }

        var selectedStatement: Statement? {
            guard let selectedStatementId else { return nil }
            return statements.first { $0.id == selectedStatementId }
        }

        var selectedStatementTotal: Decimal? {
            selectedStatement?.totalAmount
        }

        var bestPurchaseDay: Int? {
            guard let details = card.details else { return nil }
            let day = details.statementClosingDay + 1
            return day > 31 ? 1 : day
        }

        mutating func apply(_ snapshot: CreditCardStatementsSnapshot) {
            card = snapshot.card
            statements = snapshot.statements
            projections = snapshot.projections
            reconcileSelection()
        }

        mutating func reconcileSelection() {
            if let selectedStatementId, statements.contains(where: { $0.id == selectedStatementId }) {
                statementList = StatementListFeature.State(statementId: selectedStatementId)
                return
            }

            selectedStatementId = defaultStatementId
            if let selectedStatementId {
                statementList = StatementListFeature.State(statementId: selectedStatementId)
            } else {
                statementList = nil
            }
        }

        func statementDateEditorState(for statementId: UUID) -> StatementDateEditorFeature.State? {
            let orderedStatements = statements.sorted { $0.closingDate < $1.closingDate }
            guard let index = orderedStatements.firstIndex(where: { $0.id == statementId }) else {
                return nil
            }
            let statement = orderedStatements[index]
            return StatementDateEditorFeature.State(
                statementId: statement.id,
                title: Self.statementTitle(for: statement.dueDate),
                closingDate: statement.closingDate,
                dueDate: statement.dueDate,
                previousClosingDate: index > 0 ? orderedStatements[index - 1].closingDate : nil,
                nextClosingDate: index + 1 < orderedStatements.count ? orderedStatements[index + 1].closingDate : nil
            )
        }

        private static func statementTitle(for dueDate: Date) -> String {
            GranaDateFormat.dateOnlyMonthYear(dueDate)
        }
    }

    enum Action: Equatable {
        case task
        case refresh
        case snapshotLoaded(TaskResult<CreditCardStatementsSnapshot>)
        case statementSelected(UUID?)
        case statementList(StatementListFeature.Action)
        case editStatementDatesButtonTapped(UUID)
        case dateEditor(PresentationAction<StatementDateEditorFeature.Action>)
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
                state.apply(snapshot)
                state.isLoading = false
                state.hasLoaded = true
                guard state.statementList != nil else { return .none }
                return .send(.statementList(.task))

            case let .snapshotLoaded(.failure(error)):
                state.statements = []
                state.projections = []
                state.selectedStatementId = nil
                state.statementList = nil
                state.isLoading = false
                state.hasLoaded = true
                return .run { _ in
                    await noticeClient.report(error, nil)
                }

            case let .statementSelected(statementId):
                guard statementId != state.selectedStatementId else { return .none }
                state.selectedStatementId = statementId
                if let statementId {
                    state.statementList = StatementListFeature.State(statementId: statementId)
                    return .send(.statementList(.task))
                }
                state.statementList = nil
                return .none

            case .statementList:
                return .none

            case let .editStatementDatesButtonTapped(statementId):
                state.dateEditor = state.statementDateEditorState(for: statementId)
                return .none

            case .dateEditor(.presented(.delegate(.cancel))):
                state.dateEditor = nil
                return .none

            case .dateEditor(.presented(.delegate(.saved))):
                state.dateEditor = nil
                return load(&state)

            case .dateEditor:
                return .none
            }
        }
        .ifLet(\.statementList, action: \.statementList) {
            StatementListFeature()
        }
        .ifLet(\.$dateEditor, action: \.dateEditor) {
            StatementDateEditorFeature()
        }
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.isLoading = true
        return .run { [card = state.card] send in
            await send(.snapshotLoaded(TaskResult {
                try await creditCardsClient.loadStatements(card)
            }))
        }
    }
}
