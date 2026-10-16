import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("AccountsFeature")
struct AccountsFeatureTests {
    @Test("Resumo vazio usa texto amigável")
    func emptySummaryUsesFriendlyCopy() {
        let state = AccountListFeature.State()

        #expect(state.summarySubtitle == "Nenhuma conta ainda")
    }

    @Test("Carrega lista e seleciona a primeira conta visível")
    func loadsListAndSelectsFirstVisibleAccount() async {
        let firstInstitution = makeCheckingInstitution(name: "Inter")
        let secondInstitution = makeCheckingInstitution(name: "Itaú", code: "341", kind: .itau)
        let first = makeCheckingAccountItem(
            id: UUID(),
            institution: firstInstitution,
            archived: false,
            balance: 120
        )
        let second = makeCheckingAccountItem(
            id: UUID(),
            institution: secondInstitution,
            archived: true,
            balance: 40
        )
        let snapshot = AccountsSnapshot(
            items: [first, second],
            institutions: [firstInstitution, secondInstitution]
        )

        let store = TestStore(initialState: AccountsFeature.State()) {
            AccountsFeature()
        } withDependencies: {
            $0.accountsClient.loadList = { snapshot }
        }

        await store.send(.task) {
            $0.isLoading = true
        }

        await store.receive(.snapshotLoaded(.success(snapshot))) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.list.items = [first, second]
            $0.list.institutions = [firstInstitution, secondInstitution]
            $0.list.selectedAccountId = first.id
        }
    }

    @Test("Criar, arquivar e apagar abrem destinos dedicados")
    func opensDedicatedDestinations() async {
        let institution = makeCheckingInstitution()
        let account = makeCheckingAccountItem(institution: institution)
        var initialState = AccountsFeature.State()
        initialState.list.items = [account]
        initialState.list.institutions = [institution]
        initialState.list.selectedAccountId = account.id

        let store = TestStore(initialState: initialState) {
            AccountsFeature()
        }

        await store.send(.list(.addButtonTapped))
        await store.receive(.list(.delegate(.createRequested))) {
            $0.destination = .form(AccountFormFeature.State(institutions: [institution]))
        }

        await store.send(.destination(.presented(.form(.delegate(.cancel))))) {
            $0.destination = nil
        }

        await store.send(.list(.archiveButtonTapped(account.id)))
        await store.receive(.list(.delegate(.archiveRequested(account.id)))) {
            $0.destination = .archive(AccountArchiveFeature.State(account: account))
        }

        await store.send(.destination(.presented(.archive(.delegate(.cancel))))) {
            $0.destination = nil
        }

        await store.send(.list(.deleteButtonTapped(account.id)))
        await store.receive(.list(.delegate(.deleteRequested(account.id)))) {
            $0.destination = .delete(AccountDeleteFeature.State(account: account))
        }
    }

    @Test("Mostrar arquivadas reconcilia seleção no fluxo pai")
    func showArchivedReconcilesSelectionInParentFeature() async {
        let institution = makeCheckingInstitution()
        let active = makeCheckingAccountItem(institution: institution, archived: false)
        let archived = makeCheckingAccountItem(institution: institution, archived: true)
        var initialState = AccountsFeature.State()
        initialState.list.items = [active, archived]
        initialState.list.institutions = [institution]
        initialState.list.showArchived = true
        initialState.list.selectedAccountId = archived.id

        let store = TestStore(initialState: initialState) {
            AccountsFeature()
        }

        await store.send(.list(.binding(.set(\.showArchived, false)))) {
            $0.list.showArchived = false
            $0.list.selectedAccountId = active.id
        }
    }
}
