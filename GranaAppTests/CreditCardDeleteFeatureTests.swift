import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("CreditCardDeleteFeature")
struct CreditCardDeleteFeatureTests {
    @Test("Apagar cartão usa client dedicado")
    func deleteFeatureCallsDedicatedClient() async {
        let card = CreditCardListItem(
            account: .fixture(id: UUID(), institutionId: UUID(), archived: false),
            institution: nil,
            details: .fixture(accountId: UUID(), last4: "1234"),
            currentBalance: 0
        )
        let deletedIds = LockIsolated<[UUID]>([])

        let store = TestStore(
            initialState: CreditCardDeleteFeature.State(card: card)
        ) {
            CreditCardDeleteFeature()
        } withDependencies: {
            $0.creditCardsClient.delete = { id in
                deletedIds.withValue { $0.append(id) }
            }
        }

        await store.send(.confirmButtonTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.confirmed))

        #expect(deletedIds.value == [card.id])
    }
}
