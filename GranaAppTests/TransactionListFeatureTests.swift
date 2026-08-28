import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("TransactionListFeature")
struct TransactionListFeatureTests {
    @Test("Carrega snapshot remoto e lookups auxiliares")
    func appliesSnapshotAndLookups() {
        let data = makeTransactionsFixture()
        let snapshot = makeTransactionsSnapshot(
            page: TransactionRemotePage(transactions: [data.transaction], nextCursor: nil),
            accounts: [data.account],
            institutions: [data.institution],
            categories: [data.category]
        )

        var state = TransactionListFeature.State()
        state.apply(snapshot)

        #expect(state.transactionsCountText() == "1 transações")
        #expect(state.accountName(for: data.transaction).contains("Banco Inter"))
    }

    @Test("Mensagem de exclusão mostra efeitos de cartão e estornos vinculados")
    func deletePreviewIncludesCardAndLinkedRefunds() {
        let data = makeTransactionsFixture()
        let card = makeRemoteCreditCardAccount(id: UUID(), institutionId: data.institution.id)
        var purchase = makeTransaction(
            id: UUID(),
            accountId: card.id,
            categoryId: data.category.id,
            amount: 100
        )
        purchase.statementId = UUID()
        let refund = makeTransaction(
            id: UUID(),
            accountId: card.id,
            categoryId: data.category.id,
            amount: 20,
            refundOfTransactionId: purchase.id
        )
        var state = TransactionListFeature.State()
        state.apply(
            makeTransactionsSnapshot(
                page: TransactionRemotePage(transactions: [purchase, refund], nextCursor: nil),
                accounts: [card],
                institutions: [data.institution],
                categories: [data.category]
            )
        )

        let message = state.deletePreview(for: purchase)

        #expect(message.contains("Pagamentos já registrados permanecem nas faturas onde foram aplicados"))
        #expect(message.contains("1 estorno vinculado"))
    }

    @Test("Query de transações filtra por banco e tipo")
    func queryFiltersByBankAndKind() {
        let institutionA = makeRemoteInstitution(
            id: UUID(),
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.checking]
        )
        let institutionB = makeRemoteInstitution(
            id: UUID(),
            code: "102",
            name: "XP",
            kind: .xp,
            accountTypes: [.checking]
        )
        let expenseCategory = makeRemoteCategory(
            id: UUID(),
            name: "Mercado",
            kind: .expense,
            slug: "mercado"
        )
        let incomeCategory = makeRemoteCategory(
            id: UUID(),
            name: "Salário",
            kind: .income,
            slug: "salario"
        )
        let accountA = makeRemoteCheckingAccount(id: UUID(), institutionId: institutionA.id, balance: 0)
        let accountB = makeRemoteCheckingAccount(id: UUID(), institutionId: institutionB.id, balance: 0)
        let accountsById = [
            accountA.id: accountA,
            accountB.id: accountB,
        ]
        let categoriesById = [
            expenseCategory.id: expenseCategory,
            incomeCategory.id: incomeCategory,
        ]
        let query = TransactionsTableQuery(
            kindFilter: .expense,
            categoryFilter: .all,
            periodFilter: .all,
            bankFilter: .bank(institutionA.id),
            sort: .occurredAtDescending
        )

        let matchesExpense = query.matches(
            makeTransaction(id: UUID(), accountId: accountA.id, categoryId: expenseCategory.id, amount: 40),
            accountsById: accountsById,
            categoriesById: categoriesById
        )
        let matchesOtherBank = query.matches(
            makeTransaction(id: UUID(), accountId: accountB.id, categoryId: expenseCategory.id, amount: 40),
            accountsById: accountsById,
            categoriesById: categoriesById
        )
        let matchesOtherKind = query.matches(
            makeTransaction(id: UUID(), accountId: accountA.id, categoryId: incomeCategory.id, amount: 40),
            accountsById: accountsById,
            categoriesById: categoriesById
        )

        #expect(matchesExpense)
        #expect(!matchesOtherBank)
        #expect(!matchesOtherKind)
    }

    @Test("Query de transações ordena por valor decrescente com desempate estável")
    func querySortsByAmountDescending() {
        let now = Date()
        let account = makeRemoteCheckingAccount(id: UUID(), institutionId: UUID(), balance: 0)
        let category = makeRemoteCategory(
            id: UUID(),
            name: "Mercado",
            kind: .expense,
            slug: "mercado"
        )
        let query = TransactionsTableQuery(sort: .amountDescending)
        let accountsById = [account.id: account]
        let categoriesById = [category.id: category]

        let higher = makeTransaction(
            id: UUID(),
            accountId: account.id,
            categoryId: category.id,
            amount: 90,
            occurredAt: now
        )
        let lower = makeTransaction(
            id: UUID(),
            accountId: account.id,
            categoryId: category.id,
            amount: 25,
            occurredAt: now.addingTimeInterval(-60)
        )

        #expect(
            query.areInIncreasingOrder(
                higher,
                lower,
                accountsById: accountsById,
                institutionsById: [:],
                categoriesById: categoriesById
            )
        )
    }

    @Test("Filtro e ordenação funcionam localmente sem refresh remoto")
    func filtersAndSortsLocally() async {
        let data = makeTransactionsFixture()
        let incomeCategory = makeRemoteCategory(
            id: UUID(),
            name: "Salário",
            kind: .income,
            slug: "salario"
        )
        let expense = makeTransaction(
            id: UUID(),
            accountId: data.account.id,
            categoryId: data.category.id,
            amount: 20,
            occurredAt: Date().addingTimeInterval(-60)
        )
        let income = makeTransaction(
            id: UUID(),
            accountId: data.account.id,
            categoryId: incomeCategory.id,
            amount: 100,
            occurredAt: Date()
        )
        var initialState = TransactionListFeature.State()
        initialState.apply(
            makeTransactionsSnapshot(
                page: TransactionRemotePage(transactions: [expense, income], nextCursor: nil),
                accounts: [data.account],
                institutions: [data.institution],
                categories: [data.category, incomeCategory]
            )
        )
        let store = TestStore(initialState: initialState) {
            TransactionListFeature()
        }

        await store.send(.kindFilterSelected(.expense)) {
            $0.kindFilter = .expense
            $0.presentedHeaderFilter = nil
        }
        #expect(store.state.visibleTransactions().map(\.id) == [expense.id])

        await store.send(.tableSortSelected(.amountAscending)) {
            $0.tableSort = .amountAscending
        }
        #expect(store.state.visibleTransactions().map(\.id) == [expense.id])
    }
}
