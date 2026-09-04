import Foundation
import Testing
@testable import GranaApp

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
                    initialBalanceCents: 12345,
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
                    creditLimitCents: 50000,
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

    @Test("Mapeia bloqueio de apagar conta com transações vinculadas")
    func mapsDeleteBlockedByLinkedTransactionsCode() async {
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
@Suite("AccountsClient")
struct AccountsClientTests {
    @Test("Carrega apenas contas correntes com instituições e saldo atual")
    func loadsCheckingAccountsWithInstitutionsAndCurrentBalance() async throws {
        let institution = makeInstitution(
            id: UUID(),
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.checking, .creditCard]
        )
        let checkingId = UUID()
        let repository = SequencedAccountRemoteRepository(
            snapshots: [makeSnapshot(accounts: [
                makeCheckingAccount(id: checkingId, institutionId: institution.id, balance: 300),
                makeCreditCardAccount(id: UUID(), institutionId: institution.id),
            ])]
        )
        let salaryCategory = makeRemoteCategory(
            id: UUID(),
            name: "Salário",
            kind: .income,
            slug: "salario"
        )
        let groceryCategory = makeRemoteCategory(
            id: UUID(),
            name: "Mercado",
            kind: .expense,
            slug: "mercado"
        )
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [salaryCategory, groceryCategory]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: repository,
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty),
            remoteTransactions: StaticTransactionRemoteRepository(page: .init(
                transactions: [
                    makeTransaction(
                        id: UUID(),
                        accountId: checkingId,
                        categoryId: salaryCategory.id,
                        amount: 200
                    ),
                    makeTransaction(
                        id: UUID(),
                        accountId: checkingId,
                        categoryId: groceryCategory.id,
                        amount: 50
                    ),
                ],
                nextCursor: nil
            ))
        )
        let client = AccountsClient.live(container: container)

        let snapshot = try await client.loadList()

        #expect(snapshot.items.count == 1)
        #expect(snapshot.items.first?.id == checkingId)
        #expect(snapshot.items.first?.institution?.code == "077")
        #expect(snapshot.items.first?.currentBalance == 450)
        #expect(snapshot.institutions.map(\.code) == ["077"])
    }

    @Test("Encaminha criação de conta corrente")
    func createsCheckingAccount() async throws {
        let institution = makeInstitution(
            id: UUID(),
            code: "341",
            name: "Itaú",
            kind: .itau,
            accountTypes: [.checking]
        )
        let repository = SequencedAccountRemoteRepository(snapshots: [.empty])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: repository,
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let client = AccountsClient.live(container: container)

        try await client.create(
            CheckingAccountMutationInput(
                institutionId: institution.id,
                currency: "BRL",
                branchId: "0001",
                accountNumber: "1234",
                initialBalance: 150
            )
        )

        let operations = await repository.operations()
        #expect(operations.count == 1)
        #expect(operations.first?.kind == .create)
        #expect(operations.first?.input?.type == .checking)
        #expect(operations.first?.input?.institutionId == institution.id)
        #expect(operations.first?.input?.bankDetails?.accountNumber == "1234")
    }

    @Test("Encaminha edição preservando flag de arquivamento")
    func updatesCheckingAccount() async throws {
        let institution = makeInstitution(
            id: UUID(),
            code: "001",
            name: "Banco do Brasil",
            kind: .bb,
            accountTypes: [.checking]
        )
        let accountId = UUID()
        let repository = SequencedAccountRemoteRepository(snapshots: [.empty])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: repository,
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let client = AccountsClient.live(container: container)

        try await client.update(
            accountId,
            true,
            CheckingAccountMutationInput(
                institutionId: institution.id,
                currency: "BRL",
                branchId: "0001",
                accountNumber: "9999",
                initialBalance: 250
            )
        )

        let operations = await repository.operations()
        #expect(operations.first?.kind == .update)
        #expect(operations.first?.accountId == accountId)
        #expect(operations.first?.input?.archived == true)
        #expect(operations.first?.input?.bankDetails?.accountNumber == "9999")
        #expect(operations.first?.input?.initialBalance == 250)
    }

    @Test("Arquivar recarrega snapshot e preserva dados bancários")
    func setArchivedReloadsAndPreservesBankDetails() async throws {
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
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [institution]),
            remoteAccounts: repository,
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let client = AccountsClient.live(container: container)

        try await client.setArchived(accountId, true)

        let operations = await repository.operations()
        #expect(await repository.loadCallCount() == 1)
        #expect(operations.first?.kind == .update)
        #expect(operations.first?.accountId == accountId)
        #expect(operations.first?.input?.archived == true)
        #expect(operations.first?.input?.bankDetails?.branchId == "0001")
        #expect(operations.first?.input?.bankDetails?.accountNumber == "1234")
    }

    @Test("Encaminha exclusão")
    func deletesAccount() async throws {
        let repository = SequencedAccountRemoteRepository(snapshots: [.empty])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: []),
            remoteAccounts: repository,
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let client = AccountsClient.live(container: container)
        let accountId = UUID()

        try await client.delete(accountId)

        let operations = await repository.operations()
        #expect(operations.first?.kind == .delete)
        #expect(operations.first?.accountId == accountId)
    }

    @Test("Propaga erro estável de instituição não suportada")
    func surfacesUnsupportedInstitutionError() async {
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: []),
            remoteAccounts: FailingAccountRemoteRepository(error: AccountRemoteRepositoryError.unsupportedInstitution),
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let client = AccountsClient.live(container: container)

        await #expect(throws: AccountRemoteRepositoryError.unsupportedInstitution) {
            try await client.create(
                CheckingAccountMutationInput(
                    institutionId: UUID(),
                    currency: "BRL",
                    branchId: "0001",
                    accountNumber: "123",
                    initialBalance: 10
                )
            )
        }
    }

    @Test("Propaga erro estável de apagar conta com transações vinculadas")
    func surfacesDeleteBlockedByLinkedTransactionsError() async {
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: []),
            remoteAccounts: FailingAccountRemoteRepository(error: AccountRemoteRepositoryError
                .accountHasFinancialHistory),
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let client = AccountsClient.live(container: container)

        await #expect(throws: AccountRemoteRepositoryError.accountHasFinancialHistory) {
            try await client.delete(UUID())
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

private func makeSnapshot(
    accounts: [Account],
    bankDetails: [BankAccountDetails] = [],
    creditCards: [CreditCardDetails] = []
) -> AccountRemoteSnapshot {
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
                        creditLimit: 1000,
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
