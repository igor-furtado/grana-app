import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("Transaction drawer")
struct TransactionDrawerFeatureTests {
    @Test("Adicionar abre formulário de nova transação")
    func addButtonOpensNewTransactionForm() async {
        let data = makeTransactionDrawerFixture()
        var initialState = TransactionsFeature.State()
        initialState.apply(
            makeTransactionDrawerSnapshot(
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

        await store.send(.addButtonTapped)

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
        let data = makeTransactionDrawerFixture()
        let other = makeDrawerTransaction(
            id: UUID(),
            accountId: data.account.id,
            categoryId: data.category.id,
            amount: 30
        )
        var state = TransactionsFeature.State()
        state.apply(
            makeTransactionDrawerSnapshot(
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

        await store.send(.editButtonTapped(other))
        store.assert {
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

    @Test("Cancelar formulário alterado pede confirmação de descarte")
    func cancelDirtyFormAsksForDiscardConfirmation() async {
        let data = makeTransactionDrawerFixture()
        var initialState = makeTransactionDrawerFormState(data: data, existing: data.transaction)
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
        let data = makeTransactionDrawerFixture()
        var initialState = makeTransactionDrawerFormState(data: data, existing: data.transaction)
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

private func makeTransactionDrawerFixture() -> (
    institution: Institution,
    category: GranaApp.Category,
    account: Account,
    transaction: Transaction
) {
    let institution = Institution(
        id: UUID(),
        code: "077",
        name: "Banco Inter",
        kind: .inter,
        capabilities: InstitutionCapabilities(
            supportedAccountTypes: [.checking],
            supportedImportFormats: []
        ),
        createdAt: Date(),
        updatedAt: Date()
    )
    let category = GranaApp.Category(
        id: UUID(),
        parentId: nil,
        name: "Restaurantes",
        kind: .expense,
        slug: "alimentacao",
        createdAt: Date()
    )
    let account = Account(
        id: UUID(),
        type: .checking,
        initialBalance: 300,
        archived: false,
        institutionId: institution.id,
        createdAt: Date(),
        updatedAt: Date()
    )
    let transaction = makeDrawerTransaction(
        id: UUID(),
        accountId: account.id,
        categoryId: category.id,
        amount: 42
    )
    return (institution, category, account, transaction)
}

private func makeTransactionDrawerSnapshot(
    page: TransactionRemotePage = .empty,
    accounts: [Account] = [],
    institutions: [Institution] = [],
    categories: [GranaApp.Category] = []
) -> TransactionsSnapshot {
    TransactionsSnapshot(
        page: page,
        accounts: accounts,
        institutions: institutions,
        bankDetails: [],
        creditCards: [],
        categories: categories,
        statements: [],
        statementPayments: []
    )
}

private func makeTransactionDrawerFormState(
    data: (
        institution: Institution,
        category: GranaApp.Category,
        account: Account,
        transaction: Transaction
    ),
    existing: Transaction
) -> TransactionFormFeature.State {
    TransactionFormFeature.State(
        existing: existing,
        transactions: [data.transaction],
        accounts: [data.account],
        institutions: [data.institution],
        bankDetails: [],
        creditCards: [],
        categories: [data.category],
        statements: [],
        statementPayments: []
    )
}

private func makeDrawerTransaction(
    id: UUID,
    accountId: UUID,
    categoryId: UUID,
    amount: Decimal
) -> Transaction {
    Transaction(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        occurredAt: Date(),
        description: "Transação",
        createdAt: Date().addingTimeInterval(-5),
        updatedAt: Date().addingTimeInterval(-5)
    )
}
