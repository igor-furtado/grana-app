import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("TransactionDeleteFeature")
struct TransactionDeleteFeatureTests {
    @Test("Confirmar exclusão apaga e notifica sucesso")
    func confirmDeletesAndNotifies() async {
        let data = makeTransactionsFixture()
        let recorder = TransactionDeleteRecorder()
        let notices = LockIsolated<[(String, String?)]>([])
        let store = TestStore(
            initialState: TransactionDeleteFeature.State(
                transaction: data.transaction,
                impactMessage: ""
            )
        ) {
            TransactionDeleteFeature()
        } withDependencies: {
            $0.transactionsClient.delete = { id in await recorder.record(id) }
            $0.noticeClient.report = { _, _ in }
            $0.noticeClient.success = { title, message in
                notices.withValue { $0.append((title, message)) }
            }
        }

        await store.send(.confirmButtonTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }
        await store.receive(\.saveSucceeded) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.confirmed))

        #expect(await recorder.deletedIds() == [data.transaction.id])
        #expect(notices.value.first?.0 == "Transação apagada")
        #expect(notices.value.first?.1 == nil)
    }

    @Test("Falha ao apagar mantém erro local")
    func deleteFailureStoresMessage() async {
        let data = makeTransactionsFixture()
        let store = TestStore(
            initialState: TransactionDeleteFeature.State(
                transaction: data.transaction,
                impactMessage: ""
            )
        ) {
            TransactionDeleteFeature()
        } withDependencies: {
            $0.transactionsClient.delete = { _ in throw NSError(domain: "Delete", code: 1) }
            $0.noticeClient.report = { _, _ in }
            $0.noticeClient.success = { _, _ in }
        }

        await store.send(.confirmButtonTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }
        await store.receive(\.saveFailed) {
            $0.isSaving = false
            $0.saveError = NSError(domain: "Delete", code: 1).localizedDescription
        }
    }
}
