import ComposableArchitecture
import Foundation

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
