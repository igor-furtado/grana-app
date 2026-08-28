import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("TransactionFormFeature")
struct TransactionFormFeatureTests {
    @Test("Cria transação a partir do formulário")
    func buildsCreateInput() {
        let data = makeTransactionsFixture()
        var state = makeTransactionFormState(data: data)
        state.description = "Mercado"
        state.amountCents = 4250

        let input = state.mutationInput()
        #expect(input?.accountId == data.account.id)
        #expect(input?.categoryId == data.category.id)
        #expect(input?.amount == Decimal(string: "42.5"))
    }

    @Test("Trocar categoria limpa subcategoria e destino quando não é transferência")
    func changingCategoryClearsDependentSelection() {
        let account = makeRemoteCheckingAccount(id: UUID(), institutionId: UUID(), balance: 0)
        let transfer = makeRemoteCategory(id: UUID(), name: "Transferência", kind: .transfer, slug: "transferencias")
        let expense = makeRemoteCategory(id: UUID(), name: "Mercado", kind: .expense, slug: "alimentacao")
        var state = TransactionFormFeature.State(
            transactions: [],
            accounts: [account],
            institutions: [],
            bankDetails: [],
            creditCards: [],
            categories: [transfer, expense],
            statements: [],
            statementPayments: []
        )
        state.categoryId = transfer.id
        state.subcategoryId = UUID()
        state.destinationAccountId = UUID()

        state.categoryId = expense.id
        state.categorySelectionChanged()

        #expect(state.subcategoryId == nil)
        #expect(state.destinationAccountId == nil)
    }

    @Test("Cancelar formulário alterado pede confirmação de descarte")
    func cancelDirtyFormAsksForDiscardConfirmation() async {
        let data = makeTransactionsFixture()
        var initialState = makeTransactionFormState(
            data: data,
            existing: data.transaction,
            transactions: [data.transaction]
        )
        initialState.description = "Descrição alterada"
        let store = TestStore(initialState: initialState) {
            TransactionFormFeature()
        }

        await store.send(.cancelButtonTapped) {
            $0.showsDiscardConfirmation = true
        }

        await store.send(.discardChangesDismissed) {
            $0.showsDiscardConfirmation = false
        }
    }

    @Test("Salvar notifica sucesso com texto do modo atual")
    func saveSuccessNotifiesWithModeSpecificTitle() async {
        let data = makeTransactionsFixture()
        var initialState = makeTransactionFormState(
            data: data,
            existing: data.transaction,
            transactions: [data.transaction]
        )
        initialState.description = "Descrição alterada"
        let notices = LockIsolated<[String]>([])
        let store = TestStore(initialState: initialState) {
            TransactionFormFeature()
        } withDependencies: {
            $0.transactionsClient.update = { _, _ in }
            $0.noticeClient.success = { title, _ in
                notices.withValue { $0.append(title) }
            }
        }

        await store.send(.saveButtonTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }
        await store.receive(\.saveSucceeded) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved))

        #expect(notices.value == ["Transação salva"])
    }
}
