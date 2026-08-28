import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("AccountFormFeature")
struct AccountFormFeatureTests {
    @Test("Salvar criação envia payload de conta corrente")
    func formSavesNewCheckingAccount() async {
        let institution = makeCheckingInstitution()
        let createdInputs = LockIsolated<[CheckingAccountMutationInput]>([])

        let store = TestStore(
            initialState: AccountFormFeature.State(
                institutions: [institution]
            )
        ) {
            AccountFormFeature()
        } withDependencies: {
            $0.accountsClient.create = { input in
                createdInputs.withValue { $0.append(input) }
            }
        }

        await store.send(.binding(.set(\.institutionId, institution.id)))
        await store.send(.binding(.set(\.branchId, "0001"))) {
            $0.branchId = "0001"
        }
        await store.send(.binding(.set(\.accountNumber, "9988-1"))) {
            $0.accountNumber = "9988-1"
        }
        await store.send(.binding(.set(\.balanceCents, 150_000))) {
            $0.balanceCents = 150_000
        }
        await store.send(.saveButtonTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved))

        let payloads = createdInputs.value
        #expect(payloads.count == 1)
        #expect(payloads.first?.institutionId == institution.id)
        #expect(payloads.first?.accountNumber == "9988-1")
        #expect(payloads.first?.branchId == "0001")
        #expect(payloads.first?.initialBalance == Decimal(string: "1500"))
    }

    @Test("Edição carrega campos existentes")
    func editStateLoadsExistingAccount() {
        let institution = makeCheckingInstitution()
        let existing = makeCheckingAccountItem(
            institution: institution,
            balance: Decimal(string: "321.45") ?? 0,
            accountNumber: "5544-0"
        )

        let state = AccountFormFeature.State(
            existingAccount: existing,
            institutions: [institution]
        )

        #expect(state.institutionId == institution.id)
        #expect(state.branchId == "0001")
        #expect(state.accountNumber == "5544-0")
        #expect(state.balanceCents == 32145)
    }
}
