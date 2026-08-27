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

    @Test("Salvar criação envia payload dedicado do cartão")
    func formSavesNewCreditCard() async {
        let institution = Institution.fixture()
        let createdId = LockIsolated<[CreditCardMutationInput]>([])

        let store = TestStore(
            initialState: CreditCardFormFeature.State(
                institutions: [institution]
            )
        ) {
            CreditCardFormFeature()
        } withDependencies: {
            $0.creditCardsClient.create = { input in
                createdId.withValue { $0.append(input) }
            }
        }

        await store.send(.binding(.set(\.institutionId, institution.id)))
        await store.send(.binding(.set(\.cardLastFour, "1234"))) {
            $0.cardLastFour = "1234"
        }
        await store.send(.binding(.set(\.hasCreditLimit, true))) {
            $0.hasCreditLimit = true
        }
        await store.send(.binding(.set(\.creditLimitCents, 150_000))) {
            $0.creditLimitCents = 150_000
        }
        await store.send(.saveButtonTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved))

        let payloads = createdId.value
        #expect(payloads.count == 1)
        #expect(payloads.first?.institutionId == institution.id)
        #expect(payloads.first?.cardLastFour == "1234")
        #expect(payloads.first?.creditLimit == Decimal(string: "1500"))
    }

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
                title: "Outubro/2023",
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
            $0.dateEditor?.saveError = nil
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
    @Test("Tabela de lançamentos deriva categoria, subcategoria e valor localmente")
    func statementListBuildsTableRows() throws {
        let rootCategoryId = UUID()
        let subcategoryId = UUID()
        let occurredAt = Date(timeIntervalSince1970: 1_727_395_200)
        let row = StatementTransactionRow(
            transaction: Transaction(
                id: UUID(),
                accountId: UUID(),
                categoryId: rootCategoryId,
                subcategoryId: subcategoryId,
                amount: 27.98,
                occurredAt: occurredAt,
                description: "ifood *IFD*Rosa Chur",
                notes: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            category: Category(
                id: rootCategoryId,
                parentId: nil,
                name: "Alimentação",
                kind: .expense,
                slug: "alimentacao",
                createdAt: Date()
            ),
            subcategory: Category(
                id: subcategoryId,
                parentId: rootCategoryId,
                name: "Delivery",
                kind: .expense,
                slug: nil,
                createdAt: Date()
            )
        )

        let state = StatementListFeature.State(statementId: UUID(), rows: [row])
        let tableRow = try #require(state.tableRows.first)

        #expect(tableRow.occurredAt == occurredAt)
        #expect(tableRow.categoryName == "Alimentação")
        #expect(tableRow.categorySortLabel == "Alimentação")
        #expect(tableRow.categoryIcon == .food)
        #expect(tableRow.subcategoryName == "Delivery")
        #expect(tableRow.subcategoryDisplayName == "Delivery")
        #expect(tableRow.subcategorySortLabel == "Delivery")
        #expect(tableRow.description == "ifood *IFD*Rosa Chur")
        #expect(tableRow.signedAmount == -27.98)
    }


    @Test("Arquivar cartão usa client dedicado")
    func archiveFeatureCallsDedicatedClient() async {
        let card = CreditCardListItem(
            account: .fixture(id: UUID(), institutionId: UUID(), archived: false),
            institution: nil,
            details: .fixture(accountId: UUID(), last4: "1234"),
            currentBalance: 0
        )
        let archivedCalls = LockIsolated<[(UUID, Bool)]>([])

        let store = TestStore(
            initialState: CreditCardArchiveFeature.State(card: card)
        ) {
            CreditCardArchiveFeature()
        } withDependencies: {
            $0.creditCardsClient.setArchived = { id, archived in
                archivedCalls.withValue { $0.append((id, archived)) }
            }
        }

        await store.send(.confirmButtonTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.confirmed))

        let calls = archivedCalls.value
        #expect(calls.count == 1)
        #expect(calls.first?.0 == card.id)
        #expect(calls.first?.1 == true)
    }
}

private func statementDateEditorScenario() -> (
    card: CreditCardListItem,
    statement: Statement,
    updated: Statement,
    result: StatementDateUpdateResult
) {
    let card = CreditCardListItem(
        account: .fixture(id: UUID(), institutionId: UUID(), archived: false),
        institution: nil,
        details: .fixture(accountId: UUID(), last4: "1234"),
        currentBalance: 300
    )
    let statement = Statement(
        id: UUID(),
        accountId: card.id,
        closingDate: Date(timeIntervalSince1970: 1_695_556_800),
        dueDate: Date(timeIntervalSince1970: 1_696_248_000),
        netAmount: 300,
        creditReceived: 0,
        paymentApplied: 0,
        settledAt: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
    let updated = Statement(
        id: statement.id,
        accountId: card.id,
        closingDate: Date(timeIntervalSince1970: 1_695_470_400),
        dueDate: Date(timeIntervalSince1970: 1_696_334_400),
        netAmount: 300,
        creditReceived: 0,
        paymentApplied: 0,
        settledAt: nil,
        createdAt: statement.createdAt,
        updatedAt: Date()
    )
    return (
        card: card,
        statement: statement,
        updated: updated,
        result: StatementDateUpdateResult(
            statementId: statement.id,
            movedTransactionCount: 2,
            enteredTransactionCount: 1,
            exitedTransactionCount: 0,
            affectedStatementCount: 2,
            paymentDifferenceStatementCount: 1
        )
    )
}

private extension Account {
    static func fixture(id: UUID, institutionId: UUID, archived: Bool) -> Account {
        Account(
            id: id,
            type: .creditCard,
            initialBalance: 0,
            archived: archived,
            institutionId: institutionId,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

private extension Institution {
    static func fixture(
        id: UUID = UUID(),
        name: String = "Inter"
    ) -> Institution {
        Institution(
            id: id,
            code: "077",
            name: name,
            kind: .inter,
            capabilities: InstitutionCapabilities(
                supportedAccountTypes: [.creditCard],
                supportedImportFormats: [.ofx]
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

private extension CreditCardDetails {
    static func fixture(accountId: UUID, last4: String) -> CreditCardDetails {
        CreditCardDetails(
            accountId: accountId,
            cardLastFour: last4,
            creditLimit: 1000,
            statementClosingDay: 10,
            paymentDueDay: 20,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
