import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("CreditCardListFeature")
struct CreditCardListFeatureTests {
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
