import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("CreditCardListFeature")
struct CreditCardListFeatureTests {
    @Test("Lista visível respeita arquivamento sem apagar cadastro")
    func visibleItemsRespectArchivedFilterWithoutEmptyingList() {
        let institution = Institution.fixture()
        let accountId = UUID()
        let card = CreditCardListItem(
            account: .fixture(id: accountId, institutionId: institution.id, archived: true),
            institution: institution,
            details: .fixture(accountId: accountId, last4: "1234"),
            currentBalance: 300
        )
        var state = CreditCardListFeature.State(items: [card])

        #expect(state.items.map(\.id) == [card.id])
        #expect(state.visibleItems.isEmpty)
        #expect(state.hasArchivedCard)
        #expect(state.summarySubtitle == "0 cartões ativos")

        state.showArchived = true

        #expect(state.visibleItems.map(\.id) == [card.id])
        #expect(state.summarySubtitle == "1 de 1 cartões visíveis")
    }

    @Test("Selecionar cartão atualiza estado local e delega a seleção")
    func cardTapUpdatesSelectionAndDelegates() async {
        let selectedId = UUID()
        let store = TestStore(initialState: CreditCardListFeature.State()) {
            CreditCardListFeature()
        }

        await store.send(.cardTapped(selectedId)) {
            $0.selectedCardId = selectedId
        }
        await store.receive(.delegate(.cardSelected(selectedId)))
    }
}
