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

    @Test("Compra parcelada em cartão preenche metadados da mutação")
    func cardInstallmentBuildsMutationMetadata() throws {
        let calendar = try Self.makeCalendar()
        let cardId = UUID()
        let institution = makeRemoteInstitution(
            id: UUID(),
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.creditCard]
        )
        let card = makeRemoteCreditCardAccount(id: cardId, institutionId: institution.id)
        let accountSnapshot = makeRemoteSnapshot(accounts: [card])
        let category = makeRemoteCategory(id: UUID(), name: "Compras", kind: .expense, slug: "compras")
        let occurredAt = try #require(calendar.date(from: DateComponents(
            calendar: calendar,
            year: 2026,
            month: 9,
            day: 3,
            hour: 12,
            minute: 48
        )))
        var state = TransactionFormFeature.State(
            transactions: [],
            accounts: [card],
            institutions: [institution],
            bankDetails: accountSnapshot.bankDetails,
            creditCards: accountSnapshot.creditCards,
            categories: [category],
            statements: [],
            statementPayments: [],
            occurredAt: occurredAt,
            calendar: calendar
        )
        state.description = "ZARA.COM BRASIL"
        state.amountCents = 16400
        state.setInstallmentEnabled(true)
        state.setInstallmentIndex(2)
        state.setInstallmentCount(5)

        let input = try #require(state.mutationInput())
        #expect(input.purchaseType == .installment)
        #expect(input.installmentIndex == 2)
        #expect(input.installmentCount == 5)
        #expect(input.originOccurredAt == calendar.date(byAdding: .month, value: -1, to: occurredAt))
    }

    @Test("Preview retroativo usa data de referência e calendário injetados")
    func retroactivePreviewUsesInjectedReferenceDateAndCalendar() throws {
        let calendar = try Self.makeCalendar()
        let institution = makeRemoteInstitution(
            id: UUID(),
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.creditCard]
        )
        let card = makeRemoteCreditCardAccount(id: UUID(), institutionId: institution.id)
        let accountSnapshot = makeRemoteSnapshot(accounts: [card])
        let category = makeRemoteCategory(id: UUID(), name: "Compras", kind: .expense, slug: "compras")
        let referenceDate = try #require(calendar.date(from: DateComponents(
            calendar: calendar,
            year: 2026,
            month: 9,
            day: 4,
            hour: 10
        )))
        let occurredAt = try #require(calendar.date(from: DateComponents(
            calendar: calendar,
            year: 2026,
            month: 9,
            day: 3,
            hour: 22
        )))
        let state = TransactionFormFeature.State(
            transactions: [],
            accounts: [card],
            institutions: [institution],
            bankDetails: accountSnapshot.bankDetails,
            creditCards: accountSnapshot.creditCards,
            categories: [category],
            statements: [],
            statementPayments: [],
            occurredAt: occurredAt,
            calendar: calendar,
            referenceDate: referenceDate
        )

        #expect(state.requiresRetroactivePreview)
    }

    @Test("Compra em cartão sem parcelamento envia tipo à vista")
    func cardCashPurchaseBuildsCashMetadata() throws {
        let institution = makeRemoteInstitution(
            id: UUID(),
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.creditCard]
        )
        let card = makeRemoteCreditCardAccount(id: UUID(), institutionId: institution.id)
        let accountSnapshot = makeRemoteSnapshot(accounts: [card])
        let category = makeRemoteCategory(id: UUID(), name: "Compras", kind: .expense, slug: "compras")
        var state = TransactionFormFeature.State(
            transactions: [],
            accounts: [card],
            institutions: [institution],
            bankDetails: accountSnapshot.bankDetails,
            creditCards: accountSnapshot.creditCards,
            categories: [category],
            statements: [],
            statementPayments: []
        )
        state.description = "Mercado"
        state.amountCents = 4250

        let input = try #require(state.mutationInput())
        #expect(input.purchaseType == .cash)
        #expect(input.installmentIndex == nil)
        #expect(input.installmentCount == nil)
    }

    @Test("Parcelamento fica restrito a despesas em cartão")
    func installmentSelectionIsRestrictedToCardExpenses() {
        let institution = makeRemoteInstitution(
            id: UUID(),
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.checking, .creditCard]
        )
        let checking = makeRemoteCheckingAccount(id: UUID(), institutionId: institution.id, balance: 0)
        let card = makeRemoteCreditCardAccount(id: UUID(), institutionId: institution.id)
        let accountSnapshot = makeRemoteSnapshot(accounts: [checking, card])
        let category = makeRemoteCategory(id: UUID(), name: "Compras", kind: .expense, slug: "compras")
        var state = TransactionFormFeature.State(
            transactions: [],
            accounts: [card, checking],
            institutions: [institution],
            bankDetails: accountSnapshot.bankDetails,
            creditCards: accountSnapshot.creditCards,
            categories: [category],
            statements: [],
            statementPayments: []
        )
        state.description = "Mercado"
        state.amountCents = 4250
        state.setInstallmentEnabled(true)
        state.setInstallmentIndex(3)
        state.setInstallmentCount(10)

        state.accountId = checking.id
        state.accountSelectionChanged()

        #expect(state.showsInstallmentFields == false)
        #expect(state.isInstallment == false)
        #expect(state.mutationInput()?.purchaseType == nil)
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

    private static func makeCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        return calendar
    }
}
