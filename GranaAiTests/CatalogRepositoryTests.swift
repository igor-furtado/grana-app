import Foundation
import Testing
@testable import GranaAi

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
    @Test("AccountStore recarrega o catálogo remoto explicitamente")
    func accountStoreRefreshesCatalog() async {
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
        let store = AccountStore(container: container)

        await store.refreshInstitutions()
        #expect(store.institutions.map(\.code) == ["077"])
        #expect(store.supportedInstitutions(for: .creditCard).map(\.code) == ["077"])

        await store.refreshInstitutions()
        #expect(store.institutions.map(\.code) == ["341"])
        #expect(store.supportedInstitutions(for: .creditCard).isEmpty)
    }

    @MainActor
    @Test("ImportStore carrega categorias e instituições remotas por slug e code")
    func importStoreLoadsRemoteCatalogs() async {
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [
                makeCategory(slug: "nao-classificado", name: "Não Classificado", kind: .expense),
            ]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [
                makeInstitution(
                    code: "077",
                    name: "Banco Inter",
                    kind: .inter,
                    accountTypes: [.checking, .creditCard],
                    importFormats: [.ofx, .interCreditCardCSV]
                ),
            ])
        )
        let store = ImportStore(container: container)

        await store.loadInitialData()

        #expect(store.categories.rootCategory(slug: "nao-classificado")?.name == "Não Classificado")
        #expect(store.institutions.institution(code: "077")?.name == "Banco Inter")
    }

    @MainActor
    @Test("CategorizationStore carrega catálogos remotos para os consumidores")
    func categorizationStoreLoadsRemoteCatalogs() async {
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: [
                makeCategory(slug: "renda-e-pagamentos", name: "Renda e Pagamentos", kind: .income),
            ]),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [
                makeInstitution(
                    code: "341",
                    name: "Itaú",
                    kind: .itau,
                    accountTypes: [.checking],
                    importFormats: [.ofx]
                ),
            ])
        )
        let store = CategorizationStore(container: container)

        await store.loadCategories()

        #expect(store.categories.rootCategory(slug: "renda-e-pagamentos")?.name == "Renda e Pagamentos")
        #expect(store.institutions.institution(code: "341")?.kind == .itau)
    }

    @MainActor
    @Test("CategoryCatalogStore mantém estado vazio após load bem-sucedido")
    func categoryCatalogStoreSupportsEmptyState() async {
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: [])
        )
        let store = CategoryCatalogStore(container: container)

        await store.load()

        #expect(store.hasLoaded)
        #expect(!store.isLoading)
        #expect(store.loadError == nil)
        #expect(store.categories.isEmpty)
    }

    @MainActor
    @Test("InstitutionCatalogStore expõe erro remoto")
    func institutionCatalogStoreExposesErrorState() async {
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: FailingInstitutionCatalogRepository()
        )
        let store = InstitutionCatalogStore(container: container)

        await store.load()

        #expect(!store.hasLoaded)
        #expect(!store.isLoading)
        #expect(store.loadError is TestCatalogFailure)
        #expect(store.institutions.isEmpty)
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
) -> GranaAi.Category {
    GranaAi.Category(
        id: UUID(),
        parentId: nil,
        name: name,
        kind: kind,
        slug: slug,
        createdAt: Date()
    )
}

private struct FailingInstitutionCatalogRepository: InstitutionCatalogRepositoryProtocol {
    func load() async throws -> [Institution] {
        throw TestCatalogFailure.unauthorized
    }
}

private enum TestCatalogFailure: Error {
    case offline
    case unauthorized
}
