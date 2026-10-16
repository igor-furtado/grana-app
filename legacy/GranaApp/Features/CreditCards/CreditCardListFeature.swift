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
            if totalCount == 0 {
                return "Nenhum cartão ainda"
            }
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
