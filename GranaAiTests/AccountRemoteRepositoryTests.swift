import Foundation
import Testing
@testable import GranaAi

@MainActor
@Suite("AccountRemoteRepository")
struct AccountRemoteRepositoryTests {
    @Test("Mapeia contas remotas por subtipo")
    func mapsRemoteRowsBySubtype() async throws {
        let now = Date()
        let checkingId = UUID()
        let creditCardId = UUID()
        let institutionId = UUID()
        let repository = AccountRemoteRepository(
            remoteStore: FakeAccountRemoteStore(rows: [
                AccountRecordRow(
                    id: checkingId,
                    type: .checking,
                    initialBalanceCents: 12_345,
                    archived: false,
                    institutionId: institutionId,
                    currency: "BRL",
                    createdAt: now,
                    updatedAt: now,
                    branchId: "0001",
                    accountNumber: "12345-6",
                    bankCreatedAt: now,
                    bankUpdatedAt: now,
                    cardLastFour: nil,
                    creditLimitCents: nil,
                    statementClosingDay: nil,
                    paymentDueDay: nil,
                    cardCreatedAt: nil,
                    cardUpdatedAt: nil
                ),
                AccountRecordRow(
                    id: creditCardId,
                    type: .creditCard,
                    initialBalanceCents: 0,
                    archived: false,
                    institutionId: institutionId,
                    currency: "BRL",
                    createdAt: now,
                    updatedAt: now,
                    branchId: nil,
                    accountNumber: nil,
                    bankCreatedAt: nil,
                    bankUpdatedAt: nil,
                    cardLastFour: "1234",
                    creditLimitCents: 50_000,
                    statementClosingDay: 8,
                    paymentDueDay: 15,
                    cardCreatedAt: now,
                    cardUpdatedAt: now
                ),
            ])
        )

        let snapshot = try await repository.load()

        #expect(snapshot.accounts.count == 2)
        #expect(snapshot.accounts.first(where: { $0.id == checkingId })?.initialBalance == Decimal(string: "123.45"))
        #expect(snapshot.bankDetails.first(where: { $0.accountId == checkingId })?.accountNumber == "12345-6")
        #expect(snapshot.creditCards.first(where: { $0.accountId == creditCardId })?.cardLastFour == "1234")
        #expect(snapshot.creditCards.first(where: { $0.accountId == creditCardId })?.creditLimit == 500)
    }

    @Test("Mapeia code estável de instituição não suportada")
    func mapsUnsupportedInstitutionCode() async {
        let repository = AccountRemoteRepository(
            remoteStore: FakeAccountRemoteStore(
                createResponse: AccountMutationResponse(
                    ok: false,
                    code: "unsupported_institution",
                    accountId: nil
                )
            )
        )

        await #expect(throws: AccountRemoteRepositoryError.unsupportedInstitution) {
            try await repository.create(input: makeMutationInput())
        }
    }

    @Test("Mapeia bloqueio de apagar conta com histórico")
    func mapsDeleteBlockedByHistoryCode() async {
        let repository = AccountRemoteRepository(
            remoteStore: FakeAccountRemoteStore(
                deleteResponse: AccountMutationResponse(
                    ok: false,
                    code: "account_has_financial_history",
                    accountId: nil
                )
            )
        )

        await #expect(throws: AccountRemoteRepositoryError.accountHasFinancialHistory) {
            try await repository.delete(accountId: UUID())
        }
    }
}

@MainActor
@Suite("AccountStore remote load and refresh")
struct AccountStoreRemoteTests {
    @Test("Carrega contas remotas explicitamente")
    func loadsRemoteAccounts() async {
        let institution = makeInstitution(
            id: UUID(),
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.checking, .creditCard]
        )
        let repository = SequencedAccountRemoteRepository(snapshots: [
            makeSnapshot(accounts: [
                makeCheckingAccount(id: UUID(), institutionId: institution.id, balance: 300),
                makeCreditCardAccount(id: UUID(), institutionId: institution.id),
            ]),
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: repository,
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let store = AccountStore(container: container)

        await store.load()

        #expect(store.accounts.count == 2)
        #expect(store.bankDetails.count == 1)
        #expect(store.creditCards.count == 1)
        #expect(store.institutions.map(\.code) == ["077"])
    }

    @Test("Recarrega após criar conta com id final do backend")
    func refreshesAfterCreate() async throws {
        let institution = makeInstitution(
            id: UUID(),
            code: "341",
            name: "Itaú",
            kind: .itau,
            accountTypes: [.checking]
        )
        let finalId = UUID()
        let repository = SequencedAccountRemoteRepository(snapshots: [
            .empty,
            makeSnapshot(accounts: [
                makeCheckingAccount(id: finalId, institutionId: institution.id, balance: 150),
            ]),
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: repository,
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let store = AccountStore(container: container)

        await store.load()
        try await store.create(
            type: .checking,
            initialBalance: 150,
            institutionId: institution.id,
            currency: "BRL",
            bankDetails: .init(branchId: "0001", accountNumber: "1234"),
            creditCardDetails: nil
        )

        #expect(store.accounts.map(\.id) == [finalId])
        #expect(await repository.loadCallCount() == 2)
        let operations = await repository.operations()
        #expect(operations.count == 1)
        #expect(operations.first?.kind == .create)
    }

    @Test("Recarrega após editar conta")
    func refreshesAfterUpdate() async throws {
        let institution = makeInstitution(
            id: UUID(),
            code: "001",
            name: "Banco do Brasil",
            kind: .bb,
            accountTypes: [.checking]
        )
        let accountId = UUID()
        let repository = SequencedAccountRemoteRepository(snapshots: [
            makeSnapshot(accounts: [
                makeCheckingAccount(id: accountId, institutionId: institution.id, balance: 100),
            ]),
            makeSnapshot(accounts: [
                makeCheckingAccount(id: accountId, institutionId: institution.id, balance: 250, archived: true),
            ]),
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: repository,
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let store = AccountStore(container: container)

        await store.load()
        var account = try #require(store.accounts.first)
        account.initialBalance = 250
        account.archived = true

        try await store.update(
            account,
            bankDetails: .init(branchId: "0001", accountNumber: "9999"),
            creditCardDetails: nil
        )

        #expect(store.accounts.first?.initialBalance == 250)
        #expect(store.accounts.first?.archived == true)
        let operations = await repository.operations()
        #expect(operations.first?.kind == .update)
    }

    @Test("Recarrega após apagar conta")
    func refreshesAfterDelete() async throws {
        let institution = makeInstitution(
            id: UUID(),
            code: "104",
            name: "Caixa",
            kind: .caixa,
            accountTypes: [.checking]
        )
        let accountId = UUID()
        let repository = SequencedAccountRemoteRepository(snapshots: [
            makeSnapshot(accounts: [
                makeCheckingAccount(id: accountId, institutionId: institution.id, balance: 10),
            ]),
            .empty,
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: repository,
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let store = AccountStore(container: container)

        await store.load()
        try await store.delete(id: accountId)

        #expect(store.accounts.isEmpty)
        let operations = await repository.operations()
        #expect(operations.first?.kind == .delete)
    }

    @Test("Refresh carrega faturas remotas do cartão")
    func refreshLoadsRemoteStatements() async throws {
        let institution = makeInstitution(
            id: UUID(),
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.checking, .creditCard]
        )
        let accountId = UUID()
        let now = Date()
        let repository = SequencedAccountRemoteRepository(snapshots: [
            makeSnapshot(accounts: [
                makeCreditCardAccount(id: accountId, institutionId: institution.id),
            ]),
        ])
        let statement = Statement(
            id: UUID(),
            accountId: accountId,
            closingDate: now,
            dueDate: now.addingTimeInterval(86_400 * 10),
            netAmount: 250,
            creditReceived: 0,
            paymentApplied: 0,
            settledAt: nil,
            createdAt: now,
            updatedAt: now
        )
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: repository,
            remoteStatements: StaticStatementRemoteRepository(
                snapshot: StatementRemoteSnapshot(
                    statements: [statement],
                    payments: []
                )
            )
        )

        let store = AccountStore(container: container)

        await store.load()

        #expect(store.statements.map(\.id) == [statement.id])
        #expect(store.nextStatement(for: accountId)?.id == statement.id)
    }

    @Test("Propaga erro estável de instituição não suportada")
    func surfacesUnsupportedInstitutionError() async {
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: []),
            remoteAccounts: FailingAccountRemoteRepository(error: AccountRemoteRepositoryError.unsupportedInstitution),
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let store = AccountStore(container: container)

        await #expect(throws: AccountRemoteRepositoryError.unsupportedInstitution) {
            try await store.create(
                type: .checking,
                initialBalance: 10,
                institutionId: UUID(),
                currency: "BRL",
                bankDetails: .init(branchId: "0001", accountNumber: "123"),
                creditCardDetails: nil
            )
        }
    }

    @Test("Propaga erro estável de apagar conta com histórico")
    func surfacesDeleteBlockedByHistoryError() async {
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: []),
            remoteAccounts: FailingAccountRemoteRepository(error: AccountRemoteRepositoryError.accountHasFinancialHistory),
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let store = AccountStore(container: container)

        await #expect(throws: AccountRemoteRepositoryError.accountHasFinancialHistory) {
            try await store.delete(id: UUID())
        }
    }
}

private actor FakeAccountRemoteStore: AccountRemoteStore {
    let rows: [AccountRecordRow]
    let createResponse: AccountMutationResponse
    let updateResponse: AccountMutationResponse
    let deleteResponse: AccountMutationResponse

    init(
        rows: [AccountRecordRow] = [],
        createResponse: AccountMutationResponse = .init(ok: true, code: nil, accountId: UUID()),
        updateResponse: AccountMutationResponse = .init(ok: true, code: nil, accountId: nil),
        deleteResponse: AccountMutationResponse = .init(ok: true, code: nil, accountId: nil)
    ) {
        self.rows = rows
        self.createResponse = createResponse
        self.updateResponse = updateResponse
        self.deleteResponse = deleteResponse
    }

    func fetchAccounts() async throws -> [AccountRecordRow] {
        rows
    }

    func createAccount(request _: CreateAccountRequest) async throws -> AccountMutationResponse {
        createResponse
    }

    func updateAccount(request _: UpdateAccountRequest) async throws -> AccountMutationResponse {
        updateResponse
    }

    func deleteAccount(request _: DeleteAccountRequest) async throws -> AccountMutationResponse {
        deleteResponse
    }
}

private actor SequencedAccountRemoteRepository: AccountRemoteRepositoryProtocol {
    struct Operation: Equatable {
        enum Kind: Equatable {
            case create
            case update
            case delete
        }

        let kind: Kind
        let accountId: UUID?
        let input: AccountMutationInput?
    }

    private var snapshots: [AccountRemoteSnapshot]
    private var recordedOperations: [Operation] = []
    private var loads = 0

    init(snapshots: [AccountRemoteSnapshot]) {
        self.snapshots = snapshots
    }

    func load() async throws -> AccountRemoteSnapshot {
        loads += 1
        if snapshots.count > 1 {
            return snapshots.removeFirst()
        }
        return snapshots.first ?? .empty
    }

    func create(input: AccountMutationInput) async throws {
        recordedOperations.append(.init(kind: .create, accountId: nil, input: input))
    }

    func update(
        accountId: UUID,
        input: AccountMutationInput,
        cycleEffectiveFrom _: Date?
    ) async throws {
        recordedOperations.append(.init(kind: .update, accountId: accountId, input: input))
    }

    func delete(accountId: UUID) async throws {
        recordedOperations.append(.init(kind: .delete, accountId: accountId, input: nil))
    }

    func operations() -> [Operation] {
        recordedOperations
    }

    func loadCallCount() -> Int {
        loads
    }
}

private struct FailingAccountRemoteRepository: AccountRemoteRepositoryProtocol {
    let error: any Error

    func load() async throws -> AccountRemoteSnapshot {
        .empty
    }

    func create(input _: AccountMutationInput) async throws {
        throw error
    }

    func update(
        accountId _: UUID,
        input _: AccountMutationInput,
        cycleEffectiveFrom _: Date?
    ) async throws {
        throw error
    }

    func delete(accountId _: UUID) async throws {
        throw error
    }
}

private func makeMutationInput() -> AccountMutationInput {
    AccountMutationInput(
        type: .checking,
        initialBalance: 100,
        archived: false,
        institutionId: UUID(),
        currency: "BRL",
        bankDetails: .init(branchId: "0001", accountNumber: "12345-6"),
        creditCardDetails: nil
    )
}

private func makeSnapshot(accounts: [Account], bankDetails: [BankAccountDetails] = [], creditCards: [CreditCardDetails] = []) -> AccountRemoteSnapshot {
    AccountRemoteSnapshot(
        accounts: accounts,
        bankDetails: bankDetails.isEmpty
            ? accounts.compactMap { account in
                if account.type == .checking {
                    return BankAccountDetails(
                        accountId: account.id,
                        branchId: "0001",
                        accountNumber: "1234",
                        createdAt: account.createdAt,
                        updatedAt: account.updatedAt
                    )
                }
                return nil
            }
            : bankDetails,
        creditCards: creditCards.isEmpty
            ? accounts.compactMap { account in
                if account.type == .creditCard {
                    return CreditCardDetails(
                        accountId: account.id,
                        cardLastFour: "1234",
                        creditLimit: 1_000,
                        statementClosingDay: 8,
                        paymentDueDay: 15,
                        createdAt: account.createdAt,
                        updatedAt: account.updatedAt
                    )
                }
                return nil
            }
            : creditCards
    )
}

private func makeCheckingAccount(id: UUID, institutionId: UUID, balance: Decimal, archived: Bool = false) -> Account {
    let now = Date()
    return Account(
        id: id,
        type: .checking,
        initialBalance: balance,
        archived: archived,
        institutionId: institutionId,
        currency: "BRL",
        createdAt: now,
        updatedAt: now
    )
}

private func makeCreditCardAccount(id: UUID, institutionId: UUID, archived: Bool = false) -> Account {
    let now = Date()
    return Account(
        id: id,
        type: .creditCard,
        initialBalance: 0,
        archived: archived,
        institutionId: institutionId,
        currency: "BRL",
        createdAt: now,
        updatedAt: now
    )
}

private func makeInstitution(
    id: UUID = UUID(),
    code: String,
    name: String,
    kind: InstitutionKind,
    accountTypes: Set<AccountType>
) -> Institution {
    let now = Date()
    return Institution(
        id: id,
        code: code,
        name: name,
        kind: kind,
        capabilities: InstitutionCapabilities(
            supportedAccountTypes: accountTypes,
            supportedImportFormats: [.ofx]
        ),
        createdAt: now,
        updatedAt: now
    )
}
