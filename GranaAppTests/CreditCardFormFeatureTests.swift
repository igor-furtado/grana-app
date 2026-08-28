import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("CreditCardFormFeature")
struct CreditCardFormFeatureTests {
    @Test("Salvar criação envia payload dedicado do cartão")
    func formSavesNewCreditCard() async {
        let institution = Institution.fixture()
        let createdId = LockIsolated<[CreditCardMutationInput]>([])

        let store = TestStore(
            initialState: CreditCardFormFeature.State(
                institutions: [institution]
            )
        ) {
            CreditCardFormFeature()
        } withDependencies: {
            $0.creditCardsClient.create = { input in
                createdId.withValue { $0.append(input) }
            }
        }

        await store.send(.binding(.set(\.institutionId, institution.id)))
        await store.send(.binding(.set(\.cardLastFour, "1234"))) {
            $0.cardLastFour = "1234"
        }
        await store.send(.binding(.set(\.hasCreditLimit, true))) {
            $0.hasCreditLimit = true
        }
        await store.send(.binding(.set(\.creditLimitCents, 150_000))) {
            $0.creditLimitCents = 150_000
        }
        await store.send(.saveButtonTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved))

        let payloads = createdId.value
        #expect(payloads.count == 1)
        #expect(payloads.first?.institutionId == institution.id)
        #expect(payloads.first?.cardLastFour == "1234")
        #expect(payloads.first?.creditLimit == Decimal(string: "1500"))
    }
}
