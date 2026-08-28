import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("AccountDeleteFeature")
struct AccountDeleteFeatureTests {
    @Test("Apagar conta usa client dedicado")
    func deleteFeatureCallsDedicatedClient() async {
        let account = makeCheckingAccountItem()
        let deletedIds = LockIsolated<[UUID]>([])

        let store = TestStore(
            initialState: AccountDeleteFeature.State(account: account)
        ) {
            AccountDeleteFeature()
        } withDependencies: {
            $0.accountsClient.delete = { id in
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

        #expect(deletedIds.value == [account.id])
    }
}
