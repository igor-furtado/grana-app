import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("AccountArchiveFeature")
struct AccountArchiveFeatureTests {
    @Test("Arquivar conta usa client dedicado")
    func archiveFeatureCallsDedicatedClient() async {
        let account = makeCheckingAccountItem(archived: false)
        let archivedCalls = LockIsolated<[(UUID, Bool)]>([])

        let store = TestStore(
            initialState: AccountArchiveFeature.State(account: account)
        ) {
            AccountArchiveFeature()
        } withDependencies: {
            $0.accountsClient.setArchived = { id, archived in
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
        #expect(calls.first?.0 == account.id)
        #expect(calls.first?.1 == true)
    }
}
