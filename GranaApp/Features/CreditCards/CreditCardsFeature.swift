import ComposableArchitecture
import Foundation

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
