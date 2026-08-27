import ComposableArchitecture
import Foundation

@Reducer
struct CreditCardListFeature {
    @ObservableState
    struct State: Equatable {
        var items: [CreditCardListItem] = []
        var institutions: [Institution] = []
        var selectedCardId: UUID?
        var showArchived = false

        var visibleItems: [CreditCardListItem] {
            items.filter { item in
                showArchived ? true : !item.account.archived
            }
        }

        var hasArchivedCard: Bool {
            items.contains { $0.account.archived }
        }

        var visibleCount: Int {
            visibleItems.count
        }

        var summarySubtitle: String {
            let totalCount = items.count
            if hasArchivedCard {
                return showArchived
                    ? "\(visibleCount) de \(totalCount) cartões visíveis"
                    : "\(visibleCount) cartões ativos"
            }
            return "\(visibleCount) \(visibleCount == 1 ? "cartão" : "cartões")"
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case addButtonTapped
        case cardTapped(UUID)
        case editButtonTapped(UUID)
        case archiveButtonTapped(UUID)
        case deleteButtonTapped(UUID)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case createRequested
        case cardSelected(UUID)
        case editRequested(UUID)
        case archiveRequested(UUID)
        case deleteRequested(UUID)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .addButtonTapped:
                return .send(.delegate(.createRequested))

            case let .cardTapped(id):
                state.selectedCardId = id
                return .send(.delegate(.cardSelected(id)))

            case let .editButtonTapped(id):
                return .send(.delegate(.editRequested(id)))

            case let .archiveButtonTapped(id):
                return .send(.delegate(.archiveRequested(id)))

            case let .deleteButtonTapped(id):
                return .send(.delegate(.deleteRequested(id)))

            case .delegate:
                return .none
            }
        }
    }
}

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

@Reducer
struct StatementDateEditorFeature {
    @ObservableState
    struct State: Equatable {
        let statementId: UUID
        let title: String
        var closingDate: Date
        var dueDate: Date
        let previousClosingDate: Date?
        let nextClosingDate: Date?
        var isSaving = false
        var saveError: String?

        var canSave: Bool {
            guard dueDate > closingDate else { return false }
            if let previousClosingDate, closingDate <= previousClosingDate {
                return false
            }
            if let nextClosingDate, closingDate >= nextClosingDate {
                return false
            }
            return true
        }

        var validationMessage: String? {
            guard dueDate > closingDate else {
                return "A data de vencimento precisa ser posterior ao fechamento."
            }
            if let previousClosingDate, closingDate <= previousClosingDate {
                return "O fechamento precisa ficar depois da fatura anterior."
            }
            if let nextClosingDate, closingDate >= nextClosingDate {
                return "O fechamento precisa ficar antes da próxima fatura."
            }
            return nil
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case cancelButtonTapped
        case saveButtonTapped
        case saveSucceeded(StatementDateUpdateResult)
        case saveFailed(String)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case cancel
        case saved(StatementDateUpdateResult)
    }

    @Dependency(\.creditCardsClient) private var creditCardsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                state.saveError = nil
                return .none

            case .cancelButtonTapped:
                return .send(.delegate(.cancel))

            case .saveButtonTapped:
                guard state.canSave else {
                    state.saveError = state.validationMessage
                    return .none
                }
                state.isSaving = true
                state.saveError = nil
                let statementId = state.statementId
                let closingDate = state.closingDate
                let dueDate = state.dueDate
                return .run { send in
                    do {
                        let result = try await creditCardsClient.updateStatementDates(
                            statementId,
                            closingDate,
                            dueDate
                        )
                        await noticeClient.info(
                            "Datas da fatura atualizadas",
                            Self.successMessage(for: result)
                        )
                        await send(.saveSucceeded(result))
                    } catch {
                        await noticeClient.report(error, "Falha ao salvar datas da fatura")
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case let .saveSucceeded(result):
                state.isSaving = false
                return .send(.delegate(.saved(result)))

            case let .saveFailed(message):
                state.isSaving = false
                state.saveError = message
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private static func successMessage(for result: StatementDateUpdateResult) -> String {
        let moved = result.movedTransactionCount
        let transactionText = moved == 1
            ? "1 transação foi realocada."
            : "\(moved) transações foram realocadas."
        guard result.paymentDifferenceStatementCount > 0 else {
            return transactionText
        }
        let differenceText = result.paymentDifferenceStatementCount == 1
            ? " 1 fatura ficou com diferença de pagamento visível."
            : " \(result.paymentDifferenceStatementCount) faturas ficaram com diferença de pagamento visível."
        return transactionText + differenceText
    }
}

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
            if let selectedStatementId,
               statements.contains(where: { $0.id == selectedStatementId })
            {
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
            monthYearFormatter.string(from: dueDate).capitalized
        }

        private static let monthYearFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM/yyyy"
            formatter.locale = Locale(identifier: "pt_BR")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }()
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

@Reducer
struct CreditCardArchiveFeature {
    @ObservableState
    struct State: Equatable {
        let card: CreditCardListItem
        var isSaving = false
        var saveError: String?

        var targetArchived: Bool {
            !card.account.archived
        }

        var title: String {
            targetArchived ? "Arquivar cartão" : "Desarquivar cartão"
        }

        var confirmTitle: String {
            targetArchived ? "Arquivar" : "Desarquivar"
        }

        var message: String {
            targetArchived
                ? "O cartão sai dos pickers e resumos, mas mantém faturas e histórico vinculados."
                : "O cartão volta a aparecer na lista principal e pode receber novas compras e pagamentos."
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

    @Dependency(\.creditCardsClient) private var creditCardsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .cancelButtonTapped:
                return .send(.delegate(.cancel))

            case .confirmButtonTapped:
                state.isSaving = true
                state.saveError = nil
                return .run { [card = state.card, targetArchived = state.targetArchived] send in
                    do {
                        try await creditCardsClient.setArchived(card.id, targetArchived)
                        await send(.saveSucceeded)
                    } catch {
                        await noticeClient.report(error, "Falha ao atualizar cartão")
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

@Reducer
struct CreditCardDeleteFeature {
    @ObservableState
    struct State: Equatable {
        let card: CreditCardListItem
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

    @Dependency(\.creditCardsClient) private var creditCardsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .cancelButtonTapped:
                return .send(.delegate(.cancel))

            case .confirmButtonTapped:
                state.isSaving = true
                state.saveError = nil
                return .run { [card = state.card] send in
                    do {
                        try await creditCardsClient.delete(card.id)
                        await send(.saveSucceeded)
                    } catch {
                        await noticeClient.report(error, "Falha ao apagar cartão")
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

@Reducer
struct CreditCardsFeature {
    @Reducer
    enum Destination {
        case form(CreditCardFormFeature)
        case archive(CreditCardArchiveFeature)
        case delete(CreditCardDeleteFeature)
    }

    @ObservableState
    struct State: Equatable {
        var list = CreditCardListFeature.State()
        var statements: CreditCardStatementsFeature.State?
        var isLoading = false
        var hasLoaded = false

        @Presents var destination: Destination.State?

        mutating func apply(_ snapshot: CreditCardListSnapshot) {
            list.items = snapshot.items
            list.institutions = snapshot.institutions

            let visibleIds = Set(list.visibleItems.map(\.id))
            if let selectedCardId = list.selectedCardId, visibleIds.contains(selectedCardId) {
                return
            }
            list.selectedCardId = list.visibleItems.first?.id
        }

        func card(for id: UUID) -> CreditCardListItem? {
            list.items.first { $0.id == id }
        }
    }

    enum Action: Equatable {
        case task
        case refresh
        case snapshotLoaded(TaskResult<CreditCardListSnapshot>)
        case list(CreditCardListFeature.Action)
        case statements(CreditCardStatementsFeature.Action)
        case destination(PresentationAction<Destination.Action>)
    }

    @Dependency(\.creditCardsClient) private var creditCardsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Scope(state: \.list, action: \.list) {
            CreditCardListFeature()
        }

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
                return syncStatementsState(&state, forceRefresh: true)

            case let .snapshotLoaded(.failure(error)):
                state.list.items = []
                state.statements = nil
                state.isLoading = false
                state.hasLoaded = true
                return .run { _ in
                    await noticeClient.report(error, nil)
                }

            case .list(.binding(\.showArchived)):
                let previousSelection = state.list.selectedCardId
                let visibleIds = Set(state.list.visibleItems.map(\.id))
                if let previousSelection, visibleIds.contains(previousSelection) {
                    return .none
                }
                state.list.selectedCardId = state.list.visibleItems.first?.id
                return syncStatementsState(&state, forceRefresh: false)

            case .list(.binding):
                return .none

            case .list(.delegate(.createRequested)):
                state.destination = .form(CreditCardFormFeature.State(institutions: state.list.institutions))
                return .none

            case let .list(.delegate(.cardSelected(id))):
                state.list.selectedCardId = id
                return syncStatementsState(&state, forceRefresh: false)

            case let .list(.delegate(.editRequested(id))):
                guard let card = state.card(for: id) else { return .none }
                state.destination = .form(
                    CreditCardFormFeature.State(
                        existingCard: card,
                        institutions: state.list.institutions
                    )
                )
                return .none

            case let .list(.delegate(.archiveRequested(id))):
                guard let card = state.card(for: id) else { return .none }
                state.destination = .archive(CreditCardArchiveFeature.State(card: card))
                return .none

            case let .list(.delegate(.deleteRequested(id))):
                guard let card = state.card(for: id) else { return .none }
                state.destination = .delete(CreditCardDeleteFeature.State(card: card))
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

            case .statements:
                return .none
            }
        }
        .ifLet(\.statements, action: \.statements) {
            CreditCardStatementsFeature()
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.isLoading = true
        return .run { send in
            await send(.snapshotLoaded(TaskResult { try await creditCardsClient.loadList() }))
        }
    }

    private func syncStatementsState(_ state: inout State, forceRefresh: Bool) -> Effect<Action> {
        guard let selectedCardId = state.list.selectedCardId,
              let card = state.card(for: selectedCardId)
        else {
            state.statements = nil
            return .none
        }

        let action: CreditCardStatementsFeature.Action
        if var statements = state.statements, statements.card.id == selectedCardId {
            statements.card = card
            state.statements = statements
            action = forceRefresh ? .refresh : .task
        } else {
            state.statements = CreditCardStatementsFeature.State(card: card)
            action = .task
        }
        return .send(.statements(action))
    }
}

extension CreditCardsFeature.Destination.State: Equatable {}
extension CreditCardsFeature.Destination.Action: Equatable {}
