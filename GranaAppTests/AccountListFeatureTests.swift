import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("AccountListFeature")
struct AccountListFeatureTests {
    @Test("Lista visível respeita arquivamento")
    func visibleItemsRespectArchivedFilter() {
        let active = makeCheckingAccountItem(archived: false)
        let archived = makeCheckingAccountItem(archived: true)
        var state = AccountListFeature.State(
            items: [active, archived],
            institutions: []
        )

        #expect(state.visibleItems.map(\.id) == [active.id])

        state.showArchived = true

        #expect(state.visibleItems.map(\.id) == [active.id, archived.id])
    }

    @Test("Ações da lista delegam intents da tela")
    func delegatesUserIntents() async {
        let account = makeCheckingAccountItem()
        let store = TestStore(
            initialState: AccountListFeature.State(
                items: [account],
                institutions: []
            )
        ) {
            AccountListFeature()
        }

        await store.send(.addButtonTapped)
        await store.receive(.delegate(.createRequested))

        await store.send(.editButtonTapped(account.id))
        await store.receive(.delegate(.editRequested(account.id)))

        await store.send(.archiveButtonTapped(account.id))
        await store.receive(.delegate(.archiveRequested(account.id)))

        await store.send(.deleteButtonTapped(account.id))
        await store.receive(.delegate(.deleteRequested(account.id)))
    }
}
