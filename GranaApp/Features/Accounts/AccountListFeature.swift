import ComposableArchitecture
import Foundation

@Reducer
struct AccountListFeature {
    @ObservableState
    struct State: Equatable {
        var items: [AccountListItem] = []
        var institutions: [Institution] = []
        var selectedAccountId: UUID?
        var showArchived = false
        var institutionFilter = "Todas"
        var searchText = ""

        var visibleItems: [AccountListItem] {
            let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

            return items.filter { item in
                if !showArchived, item.account.archived {
                    return false
                }
                if institutionFilter != "Todas", item.institutionName != institutionFilter {
                    return false
                }
                guard !needle.isEmpty else { return true }
                return item.displayName.localizedCaseInsensitiveContains(needle)
                    || item.institutionName.localizedCaseInsensitiveContains(needle)
            }
        }

        var availableInstitutionNames: [String] {
            ["Todas"] + Array(Set(items.map(\.institutionName))).sorted()
        }

        var hasArchivedAccount: Bool {
            items.contains { $0.account.archived }
        }

        var visibleCount: Int {
            visibleItems.count
        }

        var summarySubtitle: String {
            let totalCount = items.count
            if totalCount == 0 {
                return "Nenhuma conta ainda"
            }
            if hasArchivedAccount {
                return showArchived
                    ? "\(visibleCount) de \(totalCount) contas visíveis"
                    : "\(visibleCount) contas ativas"
            }
            return "\(visibleCount) \(visibleCount == 1 ? "conta" : "contas")"
        }

        mutating func apply(_ snapshot: AccountsSnapshot) {
            items = snapshot.items
            institutions = snapshot.institutions
            reconcileSelection()
        }

        mutating func reconcileSelection() {
            let visibleIds = Set(visibleItems.map(\.id))
            if let selectedAccountId, visibleIds.contains(selectedAccountId) {
                return
            }
            selectedAccountId = visibleItems.first?.id
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case addButtonTapped
        case accountSelected(UUID)
        case editButtonTapped(UUID)
        case archiveButtonTapped(UUID)
        case deleteButtonTapped(UUID)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case createRequested
        case accountSelected(UUID)
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

            case let .accountSelected(id):
                state.selectedAccountId = id
                return .send(.delegate(.accountSelected(id)))

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
