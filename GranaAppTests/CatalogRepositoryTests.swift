import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("CategoryCatalogRepository")
struct CategoryCatalogRepositoryTests {
    @Test("Mapeia categorias remotas preservando hierarquia e slug")
    func mapsRemoteRows() async throws {
        let now = Date()
        let rootId = UUID()
        let childId = UUID()
        let repository = CategoryCatalogRepository(
            remoteStore: FakeCategoryCatalogRemoteStore(records: [
                CategoryCatalogRecord(
                    id: rootId,
                    parentId: nil,
                    name: "Não Classificado",
                    kind: .expense,
                    slug: "nao-classificado",
                    createdAt: now
                ),
                CategoryCatalogRecord(
                    id: childId,
                    parentId: rootId,
                    name: "Pendente de Revisão",
                    kind: .expense,
                    slug: nil,
                    createdAt: now
                ),
            ])
        )

        let categories = try await repository.load()

        #expect(categories.count == 2)
        #expect(categories.rootCategory(slug: "nao-classificado")?.id == rootId)
        #expect(categories.first(where: { $0.id == childId })?.parentId == rootId)
    }

    @Test("Aceita catálogo remoto vazio")
    func supportsEmptyCatalog() async throws {
        let repository = CategoryCatalogRepository(
            remoteStore: FakeCategoryCatalogRemoteStore(records: [])
        )

        let categories = try await repository.load()

        #expect(categories.isEmpty)
    }

    @Test("Propaga erro remoto ao carregar categorias")
    func propagatesRemoteFailure() async {
        let repository = CategoryCatalogRepository(
            remoteStore: FakeCategoryCatalogRemoteStore(error: TestCatalogFailure.offline)
        )

        await #expect(throws: TestCatalogFailure.self) {
            _ = try await repository.load()
        }
    }
}

@MainActor
@Suite("InstitutionCatalogRepository")
struct InstitutionCatalogRepositoryTests {
    @Test("Mapeia capacidades remotas por account type e formato de importação")
    func mapsCapabilities() async throws {
        let now = Date()
        let interId = UUID()
        let repository = InstitutionCatalogRepository(
            remoteStore: FakeInstitutionCatalogRemoteStore(records: [
                InstitutionCatalogRecord(
                    id: interId,
                    code: "077",
                    name: "Banco Inter",
                    kind: "inter",
                    supportedAccountTypes: [.checking, .creditCard],
                    supportedImportFormats: [.ofx, .interCreditCardCSV],
                    createdAt: now,
                    updatedAt: now
                ),
            ])
        )

        let institutions = try await repository.load()
        let inter = try #require(institutions.institution(code: "077"))

        #expect(inter.id == interId)
        #expect(inter.capabilities.supports(.checking))
        #expect(inter.capabilities.supports(.creditCard))
        #expect(inter.capabilities.supports(.ofx))
        #expect(inter.capabilities.supports(.interCreditCardCSV))
    }

    @Test("Busca por code ignora whitespace e respeita capability de importação")
    func findsByCodeAndCapability() async throws {
        let now = Date()
        let repository = InstitutionCatalogRepository(
            remoteStore: FakeInstitutionCatalogRemoteStore(records: [
                InstitutionCatalogRecord(
                    id: UUID(),
                    code: "341",
                    name: "Itaú",
                    kind: "itau",
                    supportedAccountTypes: [.checking],
                    supportedImportFormats: [.ofx],
                    createdAt: now,
                    updatedAt: now
                ),
            ])
        )

        let institutions = try await repository.load()

        #expect(institutions.institution(code: " 341 ")?.name == "Itaú")
        #expect(institutions.institution(code: "341", supporting: .ofx) != nil)
        #expect(institutions.institution(code: "341", supporting: .interCreditCardCSV) == nil)
    }

    @Test("Propaga erro remoto ao carregar instituições")
    func propagatesRemoteFailure() async {
        let repository = InstitutionCatalogRepository(
            remoteStore: FakeInstitutionCatalogRemoteStore(error: TestCatalogFailure.unauthorized)
        )

        await #expect(throws: TestCatalogFailure.self) {
            _ = try await repository.load()
        }
    }
}

@Suite("Catalog load and refresh")
struct CatalogLoadingTests {
    @MainActor
    @Test("AccountsClient carrega instituições remotas junto da listagem")
    func accountsClientLoadsInstitutionsWithList() async throws {
        let repository = SequencedInstitutionCatalogRepository(snapshots: [
            [makeInstitution(
                code: "077",
                name: "Banco Inter",
                kind: .inter,
                accountTypes: [.checking, .creditCard],
                importFormats: [.ofx, .interCreditCardCSV]
            )],
            [makeInstitution(
                code: "341",
                name: "Itaú",
                kind: .itau,
                accountTypes: [.checking],
                importFormats: [.ofx]
            )],
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: repository,
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty)
        )
        let client = AccountsClient.live(container: container)

        let firstSnapshot = try await client.loadList()
        let secondSnapshot = try await client.loadList()

        #expect(firstSnapshot.institutions.map(\.code) == ["077"])
        #expect(secondSnapshot.institutions.map(\.code) == ["341"])
    }

    @MainActor
    @Test("ImportClient carrega snapshot com catálogos e contas remotas")
    func importClientLoadsSnapshot() async throws {
        let institution = makeInstitution(
            code: "077",
            name: "Banco Inter",
            kind: .inter,
            accountTypes: [.checking, .creditCard],
            importFormats: [.ofx, .interCreditCardCSV]
        )
        let account = Account(
            id: UUID(),
            type: .checking,
            initialBalance: 0,
            archived: false,
            institutionId: institution.id,
            createdAt: Date(),
            updatedAt: Date()
        )
        let batch = ImportBatch(
            id: UUID(),
            sourceFilename: "extrato.ofx",
            accountId: account.id,
            rowCount: 1,
            importedAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [
                makeCategory(slug: "nao-classificado", name: "Não Classificado", kind: .expense),
            ]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [
                institution,
            ]),
            remoteAccounts: StaticAccountRemoteRepository(
                snapshot: AccountRemoteSnapshot(
                    accounts: [account],
                    bankDetails: [],
                    creditCards: []
                )
            ),
            remoteImports: StaticImportRemoteRepository(batches: [batch])
        )
        let client = ImportClient.live(container: container)

        let snapshot = try await client.loadSnapshot()

        #expect(snapshot.categories.rootCategory(slug: "nao-classificado")?.name == "Não Classificado")
        #expect(snapshot.institutions.institution(code: "077")?.name == "Banco Inter")
        #expect(snapshot.accounts.map(\.id) == [account.id])
        #expect(snapshot.batches == [batch])
    }

    @MainActor
    @Test("CategorizationClient carrega catálogos remotos para os consumidores")
    func categorizationClientLoadsContext() async throws {
        let institution = makeInstitution(
            code: "341",
            name: "Itaú",
            kind: .itau,
            accountTypes: [.checking],
            importFormats: [.ofx]
        )
        let account = Account(
            id: UUID(),
            type: .checking,
            initialBalance: 0,
            archived: false,
            institutionId: institution.id,
            createdAt: Date(),
            updatedAt: Date()
        )
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [
                makeCategory(slug: "renda-e-pagamentos", name: "Renda e Pagamentos", kind: .income),
            ]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [
                institution,
            ]),
            remoteAccounts: StaticAccountRemoteRepository(
                snapshot: AccountRemoteSnapshot(
                    accounts: [account],
                    bankDetails: [],
                    creditCards: []
                )
            )
        )
        let client = CategorizationClient.live(container: container)

        let context = try await client.loadContext()

        #expect(context.categories.rootCategory(slug: "renda-e-pagamentos")?.name == "Renda e Pagamentos")
        #expect(context.institutions.institution(code: "341")?.kind == .itau)
        #expect(context.accounts.map(\.id) == [account.id])
    }
}

private actor FakeCategoryCatalogRemoteStore: CategoryCatalogRemoteStore {
    let records: [CategoryCatalogRecord]
    let error: (any Error)?

    init(records: [CategoryCatalogRecord] = [], error: (any Error)? = nil) {
        self.records = records
        self.error = error
    }

    func fetchCategories() async throws -> [CategoryCatalogRecord] {
        if let error {
            throw error
        }
        return records
    }
}

private actor FakeInstitutionCatalogRemoteStore: InstitutionCatalogRemoteStore {
    let records: [InstitutionCatalogRecord]
    let error: (any Error)?

    init(records: [InstitutionCatalogRecord] = [], error: (any Error)? = nil) {
        self.records = records
        self.error = error
    }

    func fetchInstitutions() async throws -> [InstitutionCatalogRecord] {
        if let error {
            throw error
        }
        return records
    }
}

private actor SequencedInstitutionCatalogRepository: InstitutionCatalogRepositoryProtocol {
    private var snapshots: [[Institution]]
    private var index = 0

    init(snapshots: [[Institution]]) {
        self.snapshots = snapshots
    }

    func load() async throws -> [Institution] {
        guard !snapshots.isEmpty else { return [] }
        let current = snapshots[min(index, snapshots.count - 1)]
        index += 1
        return current
    }
}

private func makeInstitution(
    code: String,
    name: String,
    kind: InstitutionKind,
    accountTypes: Set<AccountType>,
    importFormats: Set<InstitutionImportFormat>
) -> Institution {
    let now = Date()
    return Institution(
        id: UUID(),
        code: code,
        name: name,
        kind: kind,
        capabilities: InstitutionCapabilities(
            supportedAccountTypes: accountTypes,
            supportedImportFormats: importFormats
        ),
        createdAt: now,
        updatedAt: now
    )
}

private func makeCategory(
    slug: String,
    name: String,
    kind: CategoryKind
) -> GranaApp.Category {
    GranaApp.Category(
        id: UUID(),
        parentId: nil,
        name: name,
        kind: kind,
        slug: slug,
        createdAt: Date()
    )
}

private enum TestCatalogFailure: Error {
    case offline
    case unauthorized
}
