import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("AccountFormFeature")
struct AccountFormFeatureTests {
    @Test("Salvar criação envia payload de conta corrente com agência opcional")
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
        #expect(payloads.first?.branchId == nil)
        #expect(payloads.first?.initialBalance == Decimal(string: "1500"))
    }

    @Test("Salvar criação envia payload de conta global")
    func formSavesGlobalAccount() async {
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

        await store.send(.binding(.set(\.territorialScope, .global))) {
            $0.territorialScope = .global
            $0.currency = "USD"
            $0.branchId = ""
        }
        await store.send(.binding(.set(\.accountNumber, "8897077206"))) {
            $0.accountNumber = "8897077206"
        }
        await store.send(.binding(.set(\.bankName, "Community Federal Savings Bank"))) {
            $0.bankName = "Community Federal Savings Bank"
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
        #expect(payloads.first?.territorialScope == .global)
        #expect(payloads.first?.currency == "USD")
        #expect(payloads.first?.branchId == nil)
        #expect(payloads.first?.bankName == "Community Federal Savings Bank")
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

    @Test("Criação aceita preenchimento inicial de conta corrente")
    func createStateLoadsCheckingAccountPrefill() {
        let institution = makeCheckingInstitution()

        let state = AccountFormFeature.State(
            institutions: [institution],
            checkingAccountPrefill: AccountFormFeature.CheckingAccountPrefill(
                institutionId: institution.id,
                branchId: "0001",
                accountNumber: "123"
            )
        )

        #expect(state.institutionId == institution.id)
        #expect(state.branchId == "0001")
        #expect(state.accountNumber == "123")
    }
}
