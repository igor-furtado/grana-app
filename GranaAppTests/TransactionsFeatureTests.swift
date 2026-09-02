import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("TransactionsFeature")
struct TransactionsFeatureTests {
    @Test("Adicionar abre formulário de nova transação")
    func addButtonOpensNewTransactionForm() async {
        let data = makeTransactionsFixture()
        var initialState = TransactionsFeature.State()
        initialState.list.apply(
            makeTransactionsSnapshot(
                page: TransactionRemotePage(transactions: [data.transaction], nextCursor: nil),
                accounts: [data.account],
                institutions: [data.institution],
                categories: [data.category]
            )
        )
        let store = TestStore(initialState: initialState) {
            TransactionsFeature()
        }
        store.exhaustivity = .off

        await store.send(.list(.addButtonTapped))
        await store.receive(.list(.delegate(.createRequested)))

        guard case let .editForm(formState) = store.state.destination else {
            Issue.record("Esperava formulário apresentado")
            return
        }
        #expect(formState.existing == nil)
        #expect(formState.accountId == data.account.id)
        #expect(formState.categoryId == data.category.id)
    }

    @Test("Trocar formulário sujo pede descarte antes de substituir")
    func replacingDirtyFormRequiresDiscardConfirmation() async {
        let data = makeTransactionsFixture()
        let other = makeTransaction(
            id: UUID(),
            accountId: data.account.id,
            categoryId: data.category.id,
            amount: 30
        )
        var state = TransactionsFeature.State()
        state.list.apply(
            makeTransactionsSnapshot(
                page: TransactionRemotePage(transactions: [data.transaction, other], nextCursor: nil),
                accounts: [data.account],
                institutions: [data.institution],
                categories: [data.category]
            )
        )
        state.destination = .editForm(state.formState(existing: data.transaction))
        if case var .editForm(formState) = state.destination {
            formState.description = "Descrição alterada"
            state.destination = .editForm(formState)
        }
        let store = TestStore(initialState: state) {
            TransactionsFeature()
        }
        store.exhaustivity = .off

        await store.send(.list(.editButtonTapped(other)))
        await store.receive(.list(.delegate(.editRequested(other)))) {
            $0.pendingFormPresentation = .edit(other)
            if case var .editForm(formState) = $0.destination {
                formState.showsDiscardConfirmation = true
                $0.destination = .editForm(formState)
            }
        }

        await store.send(.destination(.presented(.editForm(.discardChangesConfirmed))))
        await store.skipReceivedActions(strict: false)
        store.assert {
            $0.pendingFormPresentation = nil
            $0.destination = .editForm($0.formState(existing: other))
        }
    }

    @Test("Confirmação de delete fecha sheet e recarrega snapshot")
    func deleteConfirmationDismissesAndRefreshes() async {
        let data = makeTransactionsFixture()
        let refreshed = makeTransactionsSnapshot(
            accounts: [data.account],
            institutions: [data.institution],
            categories: [data.category]
        )
        var initialState = TransactionsFeature.State()
        initialState.list.apply(
            makeTransactionsSnapshot(
                page: TransactionRemotePage(transactions: [data.transaction], nextCursor: nil),
                accounts: [data.account],
                institutions: [data.institution],
                categories: [data.category]
            )
        )
        initialState.hasLoaded = true
        initialState.destination = .delete(initialState.deleteState(for: data.transaction))

        let store = TestStore(initialState: initialState) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionsClient.loadSnapshot = { refreshed }
        }

        await store.send(.destination(.presented(.delete(.delegate(.confirmed))))) {
            $0.destination = nil
            $0.list.isLoading = true
        }
        await store.receive(.delegate(.financialDataChanged))
        await store.receive(\.postDeleteRefreshCompleted) {
            $0.list.apply(refreshed)
            $0.list.isLoading = false
            $0.hasLoaded = true
        }
    }
}
