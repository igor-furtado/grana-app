import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("CreditCardStatementsFeature")
struct CreditCardStatementsFeatureTests {
    @Test("Selecionar fatura persistida dispara carregamento da lista de lançamentos")
    func statementsFeatureLoadsSelectedStatementTransactions() async {
        let card = CreditCardListItem(
            account: .fixture(id: UUID(), institutionId: UUID(), archived: false),
            institution: nil,
            details: .fixture(accountId: UUID(), last4: "1234"),
            currentBalance: 300
        )
        let statement = Statement(
            id: UUID(),
            accountId: card.id,
            closingDate: Date(timeIntervalSince1970: 100),
            dueDate: Date(timeIntervalSince1970: 200),
            netAmount: 300,
            creditReceived: 0,
            paymentApplied: 0,
            settledAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let row = StatementTransactionRow(
            transaction: Transaction(
                id: UUID(),
                accountId: card.id,
                categoryId: UUID(),
                amount: 30,
                occurredAt: Date(),
                description: "Padaria",
                notes: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            category: nil,
            subcategory: nil
        )

        let store = TestStore(
            initialState: CreditCardStatementsFeature.State(card: card)
        ) {
            CreditCardStatementsFeature()
        } withDependencies: {
            $0.creditCardsClient.loadStatements = { _ in
                CreditCardStatementsSnapshot(card: card, statements: [statement], projections: [])
            }
            $0.creditCardsClient.loadStatementTransactions = { _ in
                StatementTransactionsSnapshot(rows: [row])
            }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.snapshotLoaded(.success(
            CreditCardStatementsSnapshot(card: card, statements: [statement], projections: [])
        ))) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.statements = [statement]
            $0.selectedStatementId = statement.id
            $0.statementList = StatementListFeature.State(statementId: statement.id)
        }
        await store.receive(.statementList(.task)) {
            $0.statementList?.isLoading = true
        }
        await store.receive(.statementList(.snapshotLoaded(.success(
            StatementTransactionsSnapshot(rows: [row])
        )))) {
            $0.statementList?.rows = [row]
            $0.statementList?.isLoading = false
            $0.statementList?.hasLoaded = true
        }
    }

    @Test("Editar datas da fatura chama backend, mostra feedback e recarrega")
    func statementDateEditorSavesAndReloads() async {
        let scenario = statementDateEditorScenario()
        let card = scenario.card
        let statement = scenario.statement
        let updated = scenario.updated
        let result = scenario.result
        let originalClosing = statement.closingDate
        let originalDue = statement.dueDate
        let updates = LockIsolated<[(UUID, Date, Date)]>([])
        let notices = LockIsolated<[(String, String?)]>([])

        let store = TestStore(
            initialState: CreditCardStatementsFeature.State(card: card)
        ) {
            CreditCardStatementsFeature()
        } withDependencies: {
            $0.creditCardsClient.loadStatements = { _ in
                CreditCardStatementsSnapshot(card: card, statements: [updated], projections: [])
            }
            $0.creditCardsClient.loadStatementTransactions = { _ in
                StatementTransactionsSnapshot(rows: [])
            }
            $0.creditCardsClient.updateStatementDates = { statementId, closingDate, dueDate in
                updates.withValue { $0.append((statementId, closingDate, dueDate)) }
                return result
            }
            $0.noticeClient.info = { title, message in
                notices.withValue { $0.append((title, message)) }
            }
            $0.noticeClient.report = { _, _ in }
        }

        await store.send(.snapshotLoaded(.success(
            CreditCardStatementsSnapshot(card: card, statements: [statement], projections: [])
        ))) {
            $0.hasLoaded = true
            $0.statements = [statement]
            $0.selectedStatementId = statement.id
            $0.statementList = StatementListFeature.State(statementId: statement.id)
        }
        await store.receive(.statementList(.task)) {
            $0.statementList?.isLoading = true
        }
        await store.receive(.statementList(.snapshotLoaded(.success(
            StatementTransactionsSnapshot(rows: [])
        )))) {
            $0.statementList?.isLoading = false
            $0.statementList?.hasLoaded = true
        }
        await store.send(.editStatementDatesButtonTapped(statement.id)) {
            $0.dateEditor = StatementDateEditorFeature.State(
                statementId: statement.id,
                title: GranaDateFormat.monthYear(statement.dueDate),
                closingDate: originalClosing,
                dueDate: originalDue,
                previousClosingDate: nil,
                nextClosingDate: nil
            )
        }
        await store.send(.dateEditor(.presented(.binding(.set(\.closingDate, updated.closingDate))))) {
            $0.dateEditor?.closingDate = updated.closingDate
        }
        await store.send(.dateEditor(.presented(.binding(.set(\.dueDate, updated.dueDate))))) {
            $0.dateEditor?.dueDate = updated.dueDate
        }
        await store.send(.dateEditor(.presented(.saveButtonTapped))) {
            $0.dateEditor?.isSaving = true
        }
        await store.receive(.dateEditor(.presented(.saveSucceeded(result)))) {
            $0.dateEditor?.isSaving = false
        }
        await store.receive(.dateEditor(.presented(.delegate(.saved(result))))) {
            $0.dateEditor = nil
            $0.isLoading = true
        }
        await store.receive(.snapshotLoaded(.success(
            CreditCardStatementsSnapshot(card: card, statements: [updated], projections: [])
        ))) {
            $0.card = card
            $0.statements = [updated]
            $0.selectedStatementId = updated.id
            $0.statementList = StatementListFeature.State(statementId: updated.id)
            $0.isLoading = false
            $0.hasLoaded = true
        }
        await store.receive(.statementList(.task)) {
            $0.statementList?.isLoading = true
        }
        await store.receive(.statementList(.snapshotLoaded(.success(
            StatementTransactionsSnapshot(rows: [])
        )))) {
            $0.statementList?.isLoading = false
            $0.statementList?.hasLoaded = true
        }

        let update = updates.value.first
        #expect(updates.value.count == 1)
        #expect(update?.0 == statement.id)
        #expect(update?.1 == updated.closingDate)
        #expect(update?.2 == updated.dueDate)
        #expect(notices.value.first?.0 == "Datas da fatura atualizadas")
    }
}
