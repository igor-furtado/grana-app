import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("CreditCardsFeature")
struct CreditCardsFeatureTests {
    @Test("Seleciona o primeiro cartão visível ao carregar a lista")
    func loadsListAndSelectsFirstVisibleCard() async {
        let firstInstitution = Institution.fixture(name: "Inter")
        let secondInstitution = Institution.fixture(name: "Nubank")
        let firstAccountId = UUID()
        let secondAccountId = UUID()
        let first = CreditCardListItem(
            account: .fixture(id: firstAccountId, institutionId: firstInstitution.id, archived: false),
            institution: firstInstitution,
            details: .fixture(accountId: firstAccountId, last4: "1111"),
            currentBalance: 120
        )
        let second = CreditCardListItem(
            account: .fixture(id: secondAccountId, institutionId: secondInstitution.id, archived: true),
            institution: secondInstitution,
            details: .fixture(accountId: secondAccountId, last4: "2222"),
            currentBalance: 80
        )

        let store = TestStore(initialState: CreditCardsFeature.State()) {
            CreditCardsFeature()
        } withDependencies: {
            $0.creditCardsClient.loadList = {
                CreditCardListSnapshot(items: [first, second], institutions: [firstInstitution, secondInstitution])
            }
            $0.creditCardsClient.loadStatements = { card in
                CreditCardStatementsSnapshot(
                    card: card,
                    statements: [],
                    projections: []
                )
            }
        }

        await store.send(.task) {
            $0.isLoading = true
        }

        await store.receive(.snapshotLoaded(.success(
            CreditCardListSnapshot(items: [first, second], institutions: [firstInstitution, secondInstitution])
        ))) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.list.items = [first, second]
            $0.list.institutions = [firstInstitution, secondInstitution]
            $0.list.selectedCardId = first.id
            $0.statements = CreditCardStatementsFeature.State(card: first)
        }

        await store.receive(.statements(.task)) {
            $0.statements?.isLoading = true
        }
        await store.receive(.statements(.snapshotLoaded(.success(
            CreditCardStatementsSnapshot(card: first, statements: [], projections: [])
        )))) {
            $0.statements?.isLoading = false
            $0.statements?.hasLoaded = true
        }
    }
}
