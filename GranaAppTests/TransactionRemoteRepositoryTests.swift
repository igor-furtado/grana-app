import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("TransactionRemoteRepository")
struct TransactionRemoteRepositoryTests {
    @Test("Mapeia página remota e cursor estável")
    func mapsPageAndCursor() async throws {
        let now = Date()
        let firstId = UUID()
        let secondId = UUID()
        let thirdId = UUID()
        let accountId = UUID()
        let categoryId = UUID()
        let repository = TransactionRemoteRepository(
            remoteStore: FakeTransactionRemoteStore(rows: [
                makeTransactionRecordRow(
                    id: firstId,
                    accountId: accountId,
                    categoryId: categoryId,
                    amountCents: 12345,
                    occurredAt: now,
                    createdAt: now.addingTimeInterval(-10)
                ),
                makeTransactionRecordRow(
                    id: secondId,
                    accountId: accountId,
                    categoryId: categoryId,
                    amountCents: 6789,
                    occurredAt: now.addingTimeInterval(-60),
                    createdAt: now.addingTimeInterval(-70)
                ),
                makeTransactionRecordRow(
                    id: thirdId,
                    accountId: accountId,
                    categoryId: categoryId,
                    amountCents: 500,
                    occurredAt: now.addingTimeInterval(-120),
                    createdAt: now.addingTimeInterval(-130)
                ),
            ])
        )

        let page = try await repository.loadPage(cursor: nil, limit: 2)

        #expect(page.transactions.map(\.id) == [firstId, secondId])
        #expect(page.transactions.first?.amount == Decimal(string: "123.45"))
        #expect(
            page.nextCursor == TransactionRemotePageCursor(
                occurredAt: now.addingTimeInterval(-60),
                createdAt: now.addingTimeInterval(-70),
                id: secondId
            )
        )
    }

    @Test("Mapeia erro estável de transferência inválida")
    func mapsInvalidTransferDestinationCode() async {
        let repository = TransactionRemoteRepository(
            remoteStore: FakeTransactionRemoteStore(
                createResponse: .init(ok: false, code: "invalid_transfer_destination", transactionId: nil)
            )
        )

        await #expect(throws: TransactionRemoteRepositoryError.invalidTransferDestination) {
            try await repository.create(input: makeTransactionMutationInput())
        }
    }

    @Test("Mapeia erros estáveis de estorno e pagamento")
    func mapsCardRuleCodes() async {
        let invalidRefund = TransactionRemoteRepository(
            remoteStore: FakeTransactionRemoteStore(
                createResponse: .init(ok: false, code: "invalid_refund", transactionId: nil)
            )
        )
        let refundBeforePurchase = TransactionRemoteRepository(
            remoteStore: FakeTransactionRemoteStore(
                createResponse: .init(ok: false, code: "refund_before_purchase", transactionId: nil)
            )
        )
        let refundExceedsPurchase = TransactionRemoteRepository(
            remoteStore: FakeTransactionRemoteStore(
                createResponse: .init(ok: false, code: "refund_exceeds_purchase", transactionId: nil)
            )
        )
        let unappliedPayment = TransactionRemoteRepository(
            remoteStore: FakeTransactionRemoteStore(
                createResponse: .init(ok: false, code: "unapplied_payment", transactionId: nil)
            )
        )

        await #expect(throws: TransactionRemoteRepositoryError.invalidRefund) {
            try await invalidRefund.create(input: makeTransactionMutationInput())
        }
        await #expect(throws: TransactionRemoteRepositoryError.refundBeforePurchase) {
            try await refundBeforePurchase.create(input: makeTransactionMutationInput())
        }
        await #expect(throws: TransactionRemoteRepositoryError.refundExceedsPurchase) {
            try await refundExceedsPurchase.create(input: makeTransactionMutationInput())
        }
        await #expect(throws: TransactionRemoteRepositoryError.unappliedPayment) {
            try await unappliedPayment.create(input: makeTransactionMutationInput())
        }
    }

    @Test("Converte Decimal em centavos nas mutações")
    func mapsDecimalToCentsInMutationRequests() {
        let input = TransactionMutationInput(
            accountId: UUID(),
            categoryId: UUID(),
            subcategoryId: nil,
            amount: Decimal(string: "123.45") ?? 0,
            occurredAt: Date(),
            description: "Mercado",
            notes: "Sem observações",
            destinationAccountId: nil,
            refundOfTransactionId: nil
        )

        let createRequest = CreateTransactionRequest(input: input)
        let updateRequest = UpdateTransactionRequest(
            transactionId: UUID(),
            input: input
        )

        #expect(createRequest.pAmountCents == 12345)
        #expect(updateRequest.pAmountCents == 12345)
    }
}

@MainActor
@Suite("TransactionsFeature")
struct TransactionsFeatureTests {
    @Test("Carrega snapshot remoto e lookups auxiliares")
    func appliesSnapshotAndLookups() {
        let data = makeTransactionsFeatureFixture()
        let snapshot = makeTransactionsSnapshot(
            page: TransactionRemotePage(transactions: [data.transaction], nextCursor: nil),
            accounts: [data.account],
            institutions: [data.institution],
            categories: [data.category]
        )

        var state = TransactionsFeature.State()
        state.apply(snapshot)

        #expect(state.transactionsCountText() == "1 transações")
        #expect(state.accountName(for: data.transaction).contains("Banco Inter"))
    }

    @Test("Mensagem de exclusão mostra efeitos de cartão e estornos vinculados")
    func deletePreviewIncludesCardAndLinkedRefunds() {
        let data = makeTransactionsFeatureFixture()
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
        var state = TransactionsFeature.State()
        state.apply(
            makeTransactionsSnapshot(
                page: TransactionRemotePage(transactions: [purchase, refund], nextCursor: nil),
                accounts: [card],
                institutions: [data.institution],
                categories: [data.category]
            )
        )

        let message = state.deletePreview(for: purchase)

        #expect(message.contains("Faturas, créditos, pagamentos e quitações posteriores"))
        #expect(message.contains("1 estorno(s) vinculado(s)"))
    }

    @Test("TransactionsClient permite compor delete e refresh por dependência")
    func clientDeletesAndReloads() async throws {
        let data = makeTransactionsFeatureFixture()
        let refreshed = makeTransactionsSnapshot(
            accounts: [data.account],
            institutions: [data.institution],
            categories: [data.category]
        )
        let recorder = TransactionDeleteRecorder()
        let client = TransactionsClient(
            loadSnapshot: { _ in refreshed },
            create: { _ in },
            update: { _, _ in },
            delete: { id in await recorder.record(id) }
        )

        try await client.delete(data.transaction.id)
        let snapshot = try await client.loadSnapshot(TransactionsTableQuery())

        #expect(await recorder.deletedIds() == [data.transaction.id])
        #expect(snapshot.page.transactions.isEmpty)
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
}

@MainActor
@Suite("TransactionFormFeature")
struct TransactionFormFeatureTests {
    @Test("Cria transação a partir do formulário")
    func buildsCreateInput() {
        let data = makeTransactionsFeatureFixture()
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

    @Test("Selecionar estorno herda categoria da compra")
    func selectingRefundInheritsPurchaseCategory() {
        let data = makeTransactionsFeatureFixture()
        let subcategory = GranaApp.Category(
            id: UUID(),
            parentId: data.category.id,
            name: "Restaurante",
            kind: .expense,
            slug: nil,
            createdAt: Date()
        )
        var purchase = data.transaction
        purchase.subcategoryId = subcategory.id
        var state = makeTransactionFormState(
            data: data,
            transactions: [purchase],
            categories: [data.category, subcategory]
        )
        state.occurredAt = purchase.occurredAt.addingTimeInterval(60)

        state.refundOfTransactionId = purchase.id
        state.refundSelectionChanged()

        #expect(state.categoryId == purchase.categoryId)
        #expect(state.subcategoryId == purchase.subcategoryId)
    }
}

private actor TransactionDeleteRecorder {
    private var recordedIds: [UUID] = []

    func record(_ id: UUID) {
        recordedIds.append(id)
    }

    func deletedIds() -> [UUID] {
        recordedIds
    }
}

private func makeTransactionsFeatureFixture() -> (
    institution: Institution,
    category: GranaApp.Category,
    account: Account,
    transaction: Transaction
) {
    let institution = makeRemoteInstitution(
        id: UUID(),
        code: "077",
        name: "Banco Inter",
        kind: .inter,
        accountTypes: [.checking]
    )
    let category = makeRemoteCategory(
        id: UUID(),
        name: "Restaurantes",
        kind: .expense,
        slug: "alimentacao"
    )
    let account = makeRemoteCheckingAccount(
        id: UUID(),
        institutionId: institution.id,
        balance: 300
    )
    let transaction = makeTransaction(
        id: UUID(),
        accountId: account.id,
        categoryId: category.id,
        amount: 42
    )
    return (institution, category, account, transaction)
}

private func makeTransactionsSnapshot(
    page: TransactionRemotePage = .empty,
    accounts: [Account] = [],
    institutions: [Institution] = [],
    categories: [GranaApp.Category] = [],
    statements: [Statement] = [],
    statementPayments: [StatementPayment] = []
) -> TransactionsSnapshot {
    let accountSnapshot = makeRemoteSnapshot(accounts: accounts)
    return TransactionsSnapshot(
        page: page,
        accounts: accounts,
        institutions: institutions,
        bankDetails: accountSnapshot.bankDetails,
        creditCards: accountSnapshot.creditCards,
        categories: categories,
        statements: statements,
        statementPayments: statementPayments
    )
}

private func makeTransactionFormState(
    data: (
        institution: Institution,
        category: GranaApp.Category,
        account: Account,
        transaction: Transaction
    ),
    transactions: [Transaction] = [],
    categories: [GranaApp.Category]? = nil
) -> TransactionFormFeature.State {
    let accountSnapshot = makeRemoteSnapshot(accounts: [data.account])
    return TransactionFormFeature.State(
        transactions: transactions,
        accounts: [data.account],
        institutions: [data.institution],
        bankDetails: accountSnapshot.bankDetails,
        creditCards: accountSnapshot.creditCards,
        categories: categories ?? [data.category],
        statements: [],
        statementPayments: []
    )
}

private actor FakeTransactionRemoteStore: TransactionRemoteStore {
    let rows: [TransactionRecordRow]
    let createResponse: TransactionMutationResponse
    let updateResponse: TransactionMutationResponse
    let deleteResponse: TransactionMutationResponse

    init(
        rows: [TransactionRecordRow] = [],
        createResponse: TransactionMutationResponse = .init(ok: true, code: nil, transactionId: UUID()),
        updateResponse: TransactionMutationResponse = .init(ok: true, code: nil, transactionId: nil),
        deleteResponse: TransactionMutationResponse = .init(ok: true, code: nil, transactionId: nil)
    ) {
        self.rows = rows
        self.createResponse = createResponse
        self.updateResponse = updateResponse
        self.deleteResponse = deleteResponse
    }

    func fetchTransactions(request _: ListTransactionsRequest) async throws -> [TransactionRecordRow] {
        rows
    }

    func createTransaction(request _: CreateTransactionRequest) async throws -> TransactionMutationResponse {
        createResponse
    }

    func updateTransaction(request _: UpdateTransactionRequest) async throws -> TransactionMutationResponse {
        updateResponse
    }

    func deleteTransaction(request _: DeleteTransactionRequest) async throws -> TransactionMutationResponse {
        deleteResponse
    }
}

private actor SequencedTransactionRemoteRepository: TransactionRemoteRepositoryProtocol {
    struct Operation: Equatable {
        enum Kind: Equatable {
            case create
            case update
            case delete
        }

        let kind: Kind
        let transactionId: UUID?
        let input: TransactionMutationInput?
    }

    private var pages: [TransactionRemotePage]
    private var recordedOperations: [Operation] = []
    private var cursors: [TransactionRemotePageCursor?] = []
    private var loads = 0

    init(pages: [TransactionRemotePage]) {
        self.pages = pages
    }

    func loadPage(cursor: TransactionRemotePageCursor?, limit _: Int) async throws -> TransactionRemotePage {
        loads += 1
        cursors.append(cursor)
        if pages.count > 1 {
            return pages.removeFirst()
        }
        return pages.first ?? .empty
    }

    func create(input: TransactionMutationInput) async throws {
        recordedOperations.append(.init(kind: .create, transactionId: nil, input: input))
    }

    func update(transactionId: UUID, input: TransactionMutationInput) async throws {
        recordedOperations.append(.init(kind: .update, transactionId: transactionId, input: input))
    }

    func delete(transactionId: UUID) async throws {
        recordedOperations.append(.init(kind: .delete, transactionId: transactionId, input: nil))
    }

    func operations() -> [Operation] {
        recordedOperations
    }

    func requestedCursors() -> [TransactionRemotePageCursor?] {
        cursors
    }

    func loadCallCount() -> Int {
        loads
    }
}

private struct FailingTransactionRemoteRepository: TransactionRemoteRepositoryProtocol {
    let error: any Error

    func loadPage(cursor _: TransactionRemotePageCursor?, limit _: Int) async throws -> TransactionRemotePage {
        .empty
    }

    func create(input _: TransactionMutationInput) async throws {
        throw error
    }

    func update(transactionId _: UUID, input _: TransactionMutationInput) async throws {
        throw error
    }

    func delete(transactionId _: UUID) async throws {
        throw error
    }
}

private actor RefreshFailingAfterMutationRepository: TransactionRemoteRepositoryProtocol {
    private let initialPage: TransactionRemotePage
    private let refreshError: TransactionRemoteRepositoryError
    private var loadCalls = 0

    init(
        initialPage: TransactionRemotePage,
        refreshError: TransactionRemoteRepositoryError
    ) {
        self.initialPage = initialPage
        self.refreshError = refreshError
    }

    func loadPage(cursor _: TransactionRemotePageCursor?, limit _: Int) async throws -> TransactionRemotePage {
        defer { loadCalls += 1 }
        if loadCalls == 0 {
            return initialPage
        }
        throw refreshError
    }

    func create(input _: TransactionMutationInput) async throws {}

    func update(transactionId _: UUID, input _: TransactionMutationInput) async throws {}

    func delete(transactionId _: UUID) async throws {}
}

private actor SequencedStatementRemoteRepository: StatementRemoteRepositoryProtocol {
    private var snapshots: [StatementRemoteSnapshot]

    init(snapshots: [StatementRemoteSnapshot]) {
        self.snapshots = snapshots
    }

    func load() async throws -> StatementRemoteSnapshot {
        if snapshots.count > 1 {
            return snapshots.removeFirst()
        }
        return snapshots.first ?? .empty
    }

    func loadTransactions(statementId _: UUID) async throws -> [Transaction] {
        []
    }
}

private func makeTransactionRecordRow(
    id: UUID,
    accountId: UUID,
    categoryId: UUID,
    amountCents: Int64,
    occurredAt: Date,
    createdAt: Date,
    updatedAt: Date? = nil
) -> TransactionRecordRow {
    TransactionRecordRow(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        subcategoryId: nil,
        amountCents: amountCents,
        occurredAt: occurredAt,
        description: "Item \(id.uuidString.prefix(4))",
        notes: nil,
        importBatchId: nil,
        externalId: nil,
        destinationAccountId: nil,
        statementId: nil,
        refundOfTransactionId: nil,
        createdAt: createdAt,
        updatedAt: updatedAt ?? createdAt
    )
}

private func makeTransactionMutationInput() -> TransactionMutationInput {
    TransactionMutationInput(
        accountId: UUID(),
        categoryId: UUID(),
        subcategoryId: nil,
        amount: 100,
        occurredAt: Date(),
        description: "Almoço",
        notes: nil,
        destinationAccountId: nil,
        refundOfTransactionId: nil
    )
}

private func makeTransaction(
    id: UUID,
    accountId: UUID,
    categoryId: UUID,
    amount: Decimal,
    occurredAt: Date = Date(),
    description: String = "Transação",
    notes: String? = nil,
    refundOfTransactionId: UUID? = nil,
    createdAt: Date = Date().addingTimeInterval(-5)
) -> Transaction {
    Transaction(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        subcategoryId: nil,
        amount: amount,
        occurredAt: occurredAt,
        description: description,
        notes: notes,
        destinationAccountId: nil,
        refundOfTransactionId: refundOfTransactionId,
        createdAt: createdAt,
        updatedAt: createdAt
    )
}

private func makeRemoteCategory(
    id: UUID,
    name: String,
    kind: CategoryKind,
    slug: String
) -> GranaApp.Category {
    GranaApp.Category(
        id: id,
        parentId: nil,
        name: name,
        kind: kind,
        slug: slug,
        createdAt: Date()
    )
}

private func makeRemoteInstitution(
    id: UUID,
    code: String,
    name: String,
    kind: InstitutionKind,
    accountTypes: Set<AccountType>
) -> Institution {
    Institution(
        id: id,
        code: code,
        name: name,
        kind: kind,
        capabilities: InstitutionCapabilities(
            supportedAccountTypes: accountTypes,
            supportedImportFormats: []
        ),
        createdAt: Date(),
        updatedAt: Date()
    )
}

private func makeRemoteCheckingAccount(
    id: UUID,
    institutionId: UUID,
    balance: Decimal
) -> Account {
    Account(
        id: id,
        type: .checking,
        initialBalance: balance,
        archived: false,
        institutionId: institutionId,
        currency: "BRL",
        createdAt: Date(),
        updatedAt: Date()
    )
}

private func makeRemoteCreditCardAccount(
    id: UUID,
    institutionId: UUID
) -> Account {
    Account(
        id: id,
        type: .creditCard,
        initialBalance: 0,
        archived: false,
        institutionId: institutionId,
        currency: "BRL",
        createdAt: Date(),
        updatedAt: Date()
    )
}

private func makeRemoteSnapshot(
    accounts: [Account]
) -> AccountRemoteSnapshot {
    AccountRemoteSnapshot(
        accounts: accounts,
        bankDetails: accounts
            .filter { $0.type == .checking }
            .map { account in
                BankAccountDetails(
                    accountId: account.id,
                    branchId: "0001",
                    accountNumber: "1234",
                    createdAt: account.createdAt,
                    updatedAt: account.updatedAt
                )
            },
        creditCards: accounts
            .filter { $0.type == .creditCard }
            .map { account in
                CreditCardDetails(
                    accountId: account.id,
                    cardLastFour: "1234",
                    creditLimit: 1000,
                    statementClosingDay: 8,
                    paymentDueDay: 15,
                    createdAt: account.createdAt,
                    updatedAt: account.updatedAt
                )
            }
    )
}

private func makeStatement(
    accountId: UUID,
    amount: Decimal
) -> Statement {
    let now = Date()
    return Statement(
        id: UUID(),
        accountId: accountId,
        closingDate: now,
        dueDate: now.addingTimeInterval(86400 * 10),
        netAmount: amount,
        creditReceived: 0,
        paymentApplied: 0,
        settledAt: nil,
        createdAt: now,
        updatedAt: now
    )
}
