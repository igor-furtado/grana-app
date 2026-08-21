import Foundation
import Testing
@testable import GranaAi

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
                    amountCents: 12_345,
                    occurredAt: now,
                    createdAt: now.addingTimeInterval(-10)
                ),
                makeTransactionRecordRow(
                    id: secondId,
                    accountId: accountId,
                    categoryId: categoryId,
                    amountCents: 6_789,
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

        #expect(createRequest.pAmountCents == 12_345)
        #expect(updateRequest.pAmountCents == 12_345)
    }
}

@MainActor
@Suite("TransactionStore remote load and refresh")
struct TransactionStoreRemoteTests {
    @Test("Carrega primeira página remota e lookups auxiliares")
    func loadsFirstPageAndLookups() async {
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
        let repository = SequencedTransactionRemoteRepository(pages: [
            TransactionRemotePage(
                transactions: [
                    makeTransaction(
                        id: UUID(),
                        accountId: account.id,
                        categoryId: category.id,
                        amount: 42
                    ),
                ],
                nextCursor: TransactionRemotePageCursor(
                    occurredAt: Date().addingTimeInterval(-60),
                    createdAt: Date().addingTimeInterval(-60),
                    id: UUID()
                )
            ),
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [category]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: StaticAccountRemoteRepository(
                snapshot: makeRemoteSnapshot(accounts: [account])
            ),
            remoteTransactions: repository
        )
        let store = TransactionStore(container: container)

        await store.load()

        #expect(store.transactions.count == 1)
        #expect(store.accounts.map(\.id) == [account.id])
        #expect(store.rootCategories.map(\.id) == [category.id])
        #expect(store.institutions.map(\.code) == ["077"])
        #expect(store.hasMoreTransactions == true)
    }

    @Test("Carrega página seguinte com cursor estável")
    func loadsNextPage() async {
        let institution = makeRemoteInstitution(
            id: UUID(),
            code: "341",
            name: "Itaú",
            kind: .itau,
            accountTypes: [.checking]
        )
        let category = makeRemoteCategory(
            id: UUID(),
            name: "Salário",
            kind: .income,
            slug: "renda"
        )
        let account = makeRemoteCheckingAccount(
            id: UUID(),
            institutionId: institution.id,
            balance: 0
        )
        let first = makeTransaction(id: UUID(), accountId: account.id, categoryId: category.id, amount: 100)
        let second = makeTransaction(
            id: UUID(),
            accountId: account.id,
            categoryId: category.id,
            amount: 80,
            occurredAt: first.occurredAt.addingTimeInterval(-60),
            createdAt: first.createdAt.addingTimeInterval(-60)
        )
        let cursor = TransactionRemotePageCursor(
            occurredAt: first.occurredAt,
            createdAt: first.createdAt,
            id: first.id
        )
        let repository = SequencedTransactionRemoteRepository(pages: [
            TransactionRemotePage(transactions: [first], nextCursor: cursor),
            TransactionRemotePage(transactions: [second], nextCursor: nil),
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [category]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: StaticAccountRemoteRepository(
                snapshot: makeRemoteSnapshot(accounts: [account])
            ),
            remoteTransactions: repository
        )
        let store = TransactionStore(container: container)

        await store.load()
        await store.loadMoreTransactions()

        #expect(store.transactions.map(\.id) == [first.id, second.id])
        #expect(store.hasMoreTransactions == false)
        let requestedCursors = await repository.requestedCursors()
        #expect(requestedCursors == [nil, cursor])
    }

    @Test("Recarrega após criar transação")
    func refreshesAfterCreate() async throws {
        let institution = makeRemoteInstitution(
            id: UUID(),
            code: "001",
            name: "Banco do Brasil",
            kind: .bb,
            accountTypes: [.checking]
        )
        let category = makeRemoteCategory(
            id: UUID(),
            name: "Mercado",
            kind: .expense,
            slug: "alimentacao"
        )
        let account = makeRemoteCheckingAccount(
            id: UUID(),
            institutionId: institution.id,
            balance: 0
        )
        let created = makeTransaction(id: UUID(), accountId: account.id, categoryId: category.id, amount: 55)
        let repository = SequencedTransactionRemoteRepository(pages: [
            .empty,
            TransactionRemotePage(transactions: [created], nextCursor: nil),
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [category]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: StaticAccountRemoteRepository(
                snapshot: makeRemoteSnapshot(accounts: [account])
            ),
            remoteTransactions: repository
        )
        let store = TransactionStore(container: container)

        await store.load()
        try await store.add(
            accountId: account.id,
            categoryId: category.id,
            subcategoryId: nil,
            amount: 55,
            occurredAt: created.occurredAt,
            description: created.description,
            notes: created.notes
        )

        #expect(store.transactions.map(\.id) == [created.id])
        #expect(await repository.loadCallCount() == 2)
        let operations = await repository.operations()
        #expect(operations.first?.kind == .create)
    }

    @Test("Recarrega após editar transação")
    func refreshesAfterUpdate() async throws {
        let institution = makeRemoteInstitution(
            id: UUID(),
            code: "104",
            name: "Caixa",
            kind: .caixa,
            accountTypes: [.checking]
        )
        let category = makeRemoteCategory(
            id: UUID(),
            name: "Freelance",
            kind: .income,
            slug: "renda"
        )
        let account = makeRemoteCheckingAccount(
            id: UUID(),
            institutionId: institution.id,
            balance: 0
        )
        let original = makeTransaction(id: UUID(), accountId: account.id, categoryId: category.id, amount: 10)
        let updated = makeTransaction(
            id: original.id,
            accountId: account.id,
            categoryId: category.id,
            amount: 25,
            occurredAt: original.occurredAt,
            createdAt: original.createdAt
        )
        let repository = SequencedTransactionRemoteRepository(pages: [
            TransactionRemotePage(transactions: [original], nextCursor: nil),
            TransactionRemotePage(transactions: [updated], nextCursor: nil),
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [category]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: StaticAccountRemoteRepository(
                snapshot: makeRemoteSnapshot(accounts: [account])
            ),
            remoteTransactions: repository
        )
        let store = TransactionStore(container: container)

        await store.load()
        var transaction = try #require(store.transactions.first)
        transaction.amount = 25

        try await store.update(transaction)

        #expect(store.transactions.first?.amount == 25)
        let operations = await repository.operations()
        #expect(operations.first?.kind == .update)
    }

    @Test("Recarrega após apagar transação")
    func refreshesAfterDelete() async throws {
        let institution = makeRemoteInstitution(
            id: UUID(),
            code: "336",
            name: "C6",
            kind: .c6,
            accountTypes: [.checking]
        )
        let category = makeRemoteCategory(
            id: UUID(),
            name: "Transferência",
            kind: .transfer,
            slug: "transferencias"
        )
        let account = makeRemoteCheckingAccount(
            id: UUID(),
            institutionId: institution.id,
            balance: 0
        )
        let transaction = makeTransaction(id: UUID(), accountId: account.id, categoryId: category.id, amount: 15)
        let repository = SequencedTransactionRemoteRepository(pages: [
            TransactionRemotePage(transactions: [transaction], nextCursor: nil),
            .empty,
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [category]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: StaticAccountRemoteRepository(
                snapshot: makeRemoteSnapshot(accounts: [account])
            ),
            remoteTransactions: repository
        )
        let store = TransactionStore(container: container)

        await store.load()
        try await store.delete(id: transaction.id)

        #expect(store.transactions.isEmpty)
        let operations = await repository.operations()
        #expect(operations.first?.kind == .delete)
    }

    @Test("Propaga erro estável de destino inválido")
    func surfacesStableError() async {
        let category = makeRemoteCategory(
            id: UUID(),
            name: "Transferência",
            kind: .transfer,
            slug: "transferencias"
        )
        let institution = makeRemoteInstitution(
            id: UUID(),
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.checking]
        )
        let account = makeRemoteCheckingAccount(
            id: UUID(),
            institutionId: institution.id,
            balance: 0
        )
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [category]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: StaticAccountRemoteRepository(
                snapshot: makeRemoteSnapshot(accounts: [account])
            ),
            remoteTransactions: FailingTransactionRemoteRepository(
                error: TransactionRemoteRepositoryError.invalidTransferDestination
            )
        )
        let store = TransactionStore(container: container)

        await #expect(throws: TransactionRemoteRepositoryError.invalidTransferDestination) {
            try await store.add(
                accountId: account.id,
                categoryId: category.id,
                subcategoryId: nil,
                amount: 30,
                occurredAt: Date(),
                description: "Transferência inválida",
                notes: nil,
                destinationAccountId: account.id
            )
        }
    }

    @Test("Repropaga falha de refresh após criar transação")
    func rethrowsRefreshFailureAfterCreate() async {
        let category = makeRemoteCategory(
            id: UUID(),
            name: "Mercado",
            kind: .expense,
            slug: "alimentacao"
        )
        let institution = makeRemoteInstitution(
            id: UUID(),
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.checking]
        )
        let account = makeRemoteCheckingAccount(
            id: UUID(),
            institutionId: institution.id,
            balance: 0
        )
        let repository = RefreshFailingAfterMutationRepository(
            initialPage: .empty,
            refreshError: TransactionRemoteRepositoryError.unexpectedResponse
        )
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [category]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: StaticAccountRemoteRepository(
                snapshot: makeRemoteSnapshot(accounts: [account])
            ),
            remoteTransactions: repository
        )
        let store = TransactionStore(container: container)

        await store.load()

        await #expect(throws: TransactionRemoteRepositoryError.unexpectedResponse) {
            try await store.add(
                accountId: account.id,
                categoryId: category.id,
                subcategoryId: nil,
                amount: 30,
                occurredAt: Date(),
                description: "Mercado",
                notes: nil
            )
        }
        #expect(store.lastError as? TransactionRemoteRepositoryError == .unexpectedResponse)
    }
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
        refundOfTransactionId: nil,
        createdAt: createdAt,
        updatedAt: createdAt
    )
}

private func makeRemoteCategory(
    id: UUID,
    name: String,
    kind: CategoryKind,
    slug: String
) -> GranaAi.Category {
    GranaAi.Category(
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

private func makeRemoteSnapshot(
    accounts: [Account]
) -> AccountRemoteSnapshot {
    AccountRemoteSnapshot(
        accounts: accounts,
        bankDetails: accounts.map { account in
            BankAccountDetails(
                accountId: account.id,
                branchId: "0001",
                accountNumber: "1234",
                createdAt: account.createdAt,
                updatedAt: account.updatedAt
            )
        },
        creditCards: []
    )
}
