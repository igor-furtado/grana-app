import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("CreditCardArchiveFeature")
struct CreditCardArchiveFeatureTests {
    @Test("Arquivar cartão usa client dedicado")
    func archiveFeatureCallsDedicatedClient() async {
        let card = CreditCardListItem(
            account: .fixture(id: UUID(), institutionId: UUID(), archived: false),
            institution: nil,
            details: .fixture(accountId: UUID(), last4: "1234"),
            currentBalance: 0
        )
        let archivedCalls = LockIsolated<[(UUID, Bool)]>([])

        let store = TestStore(
            initialState: CreditCardArchiveFeature.State(card: card)
        ) {
            CreditCardArchiveFeature()
        } withDependencies: {
            $0.creditCardsClient.setArchived = { id, archived in
                archivedCalls.withValue { $0.append((id, archived)) }
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

        let calls = archivedCalls.value
        #expect(calls.count == 1)
        #expect(calls.first?.0 == card.id)
        #expect(calls.first?.1 == true)
    }
}
