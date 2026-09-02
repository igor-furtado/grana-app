import ComposableArchitecture
import Testing
@testable import GranaApp

@MainActor
@Suite("AppFeature")
struct AppFeatureTests {
    @Test("Mudança financeira recarrega read models financeiros")
    func financialDataChangeRefreshesFinancialReadModels() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.accountsClient.loadList = { .empty }
            $0.creditCardsClient.loadList = { .empty }
            $0.transactionsClient.loadSnapshot = { .empty }
        }
        store.exhaustivity = .off

        await store.send(.importFeature(.delegate(.financialDataChanged)))

        await store.receive(.accounts(.refresh)) {
            $0.accounts.isLoading = true
        }
        await store.receive(.creditCards(.refresh)) {
            $0.creditCards.isLoading = true
        }
        await store.receive(.transactions(.refresh)) {
            $0.transactions.list.isLoading = true
        }

        await store.skipReceivedActions(strict: false)
    }

    @Test("Mutação de transação recarrega faturas")
    func transactionMutationRefreshesStatements() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.creditCardsClient.loadList = { .empty }
        }
        store.exhaustivity = .off

        await store.send(.transactions(.delegate(.financialDataChanged)))

        await store.receive(.creditCards(.refresh)) {
            $0.creditCards.isLoading = true
        }

        await store.skipReceivedActions(strict: false)
    }
}
