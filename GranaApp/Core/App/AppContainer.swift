import Foundation

/// Composition Root da camada de dados online-only. Concentra repositories e
/// serviços expostos pras Stores.
final class AppContainer {
    private let authClient: (any AuthClientProtocol)?
    let categoryCatalog: any CategoryCatalogRepositoryProtocol
    let institutionCatalog: any InstitutionCatalogRepositoryProtocol
    let remoteAccounts: any AccountRemoteRepositoryProtocol
    let remoteDashboard: any DashboardRemoteRepositoryProtocol
    let remoteStatements: any StatementRemoteRepositoryProtocol
    let remoteTransactions: any TransactionRemoteRepositoryProtocol
    let remoteImports: any ImportRemoteRepositoryProtocol
    private let granaAI: (any GranaAIClassificationClientProtocol)?

    /// Pipeline local mínimo de classificação para revisão de importação.
    lazy var categorization: CategorizationService = .init(
        categories: categoryCatalog,
        granaAI: granaAI
    )
    lazy var categorizationFeedback: GranaAIFeedbackService = .init(granaAI: granaAI)

    private init(
        authClient: (any AuthClientProtocol)? = nil,
        categoryCatalog: (any CategoryCatalogRepositoryProtocol)? = nil,
        institutionCatalog: (any InstitutionCatalogRepositoryProtocol)? = nil,
        remoteAccounts: (any AccountRemoteRepositoryProtocol)? = nil,
        remoteDashboard: (any DashboardRemoteRepositoryProtocol)? = nil,
        remoteStatements: (any StatementRemoteRepositoryProtocol)? = nil,
        remoteTransactions: (any TransactionRemoteRepositoryProtocol)? = nil,
        remoteImports: (any ImportRemoteRepositoryProtocol)? = nil,
        granaAI: (any GranaAIClassificationClientProtocol)? = GranaAIProcessClient.defaultIfAvailable()
    ) {
        self.authClient = authClient
        self.granaAI = granaAI
        if let categoryCatalog {
            self.categoryCatalog = categoryCatalog
        } else if let authClient {
            self.categoryCatalog = CategoryCatalogRepository(
                remoteStore: SupabaseCategoryCatalogRemoteStore(authClient: authClient)
            )
        } else {
            self.categoryCatalog = AuthRequiredCategoryCatalogRepository()
        }

        if let institutionCatalog {
            self.institutionCatalog = institutionCatalog
        } else if let authClient {
            self.institutionCatalog = InstitutionCatalogRepository(
                remoteStore: SupabaseInstitutionCatalogRemoteStore(authClient: authClient)
            )
        } else {
            self.institutionCatalog = AuthRequiredInstitutionCatalogRepository()
        }

        if let remoteAccounts {
            self.remoteAccounts = remoteAccounts
        } else if let authClient {
            self.remoteAccounts = AccountRemoteRepository(
                remoteStore: SupabaseAccountRemoteStore(authClient: authClient)
            )
        } else {
            self.remoteAccounts = AuthRequiredAccountRemoteRepository()
        }

        if let remoteDashboard {
            self.remoteDashboard = remoteDashboard
        } else if let authClient {
            self.remoteDashboard = DashboardRemoteRepository(
                remoteStore: SupabaseDashboardRemoteStore(authClient: authClient)
            )
        } else {
            self.remoteDashboard = AuthRequiredDashboardRemoteRepository()
        }

        if let remoteStatements {
            self.remoteStatements = remoteStatements
        } else if let authClient {
            self.remoteStatements = StatementRemoteRepository(
                remoteStore: SupabaseStatementRemoteStore(authClient: authClient)
            )
        } else {
            self.remoteStatements = AuthRequiredStatementRemoteRepository()
        }

        if let remoteTransactions {
            self.remoteTransactions = remoteTransactions
        } else if let authClient {
            self.remoteTransactions = TransactionRemoteRepository(
                remoteStore: SupabaseTransactionRemoteStore(authClient: authClient)
            )
        } else {
            self.remoteTransactions = AuthRequiredTransactionRemoteRepository()
        }

        if let remoteImports {
            self.remoteImports = remoteImports
        } else if let authClient {
            self.remoteImports = ImportRemoteRepository(
                remoteStore: SupabaseImportRemoteStore(authClient: authClient)
            )
        } else {
            self.remoteImports = AuthRequiredImportRemoteRepository()
        }
    }

    static func setup(authClient: (any AuthClientProtocol)? = nil) -> AppContainer {
        AppContainer(authClient: authClient)
    }

    static func placeholder() -> AppContainer {
        AppContainer()
    }

    static func inMemoryForTesting() -> AppContainer {
        AppContainer(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: []),
            remoteAccounts: StaticAccountRemoteRepository(snapshot: .empty),
            remoteDashboard: StaticDashboardRemoteRepository(snapshot: .empty),
            remoteStatements: StaticStatementRemoteRepository(snapshot: .empty),
            remoteTransactions: StaticTransactionRemoteRepository(page: .empty),
            remoteImports: StaticImportRemoteRepository(batches: []),
            granaAI: nil
        )
    }

    static func inMemoryForTesting(
        categoryCatalog: any CategoryCatalogRepositoryProtocol,
        institutionCatalog: any InstitutionCatalogRepositoryProtocol,
        remoteAccounts: (any AccountRemoteRepositoryProtocol)? = nil,
        remoteDashboard: (any DashboardRemoteRepositoryProtocol)? = nil,
        remoteStatements: (any StatementRemoteRepositoryProtocol)? = nil,
        remoteTransactions: (any TransactionRemoteRepositoryProtocol)? = nil,
        remoteImports: (any ImportRemoteRepositoryProtocol)? = nil,
        granaAI: (any GranaAIClassificationClientProtocol)? = nil
    ) -> AppContainer {
        AppContainer(
            categoryCatalog: categoryCatalog,
            institutionCatalog: institutionCatalog,
            remoteAccounts: remoteAccounts ?? StaticAccountRemoteRepository(snapshot: .empty),
            remoteDashboard: remoteDashboard ?? StaticDashboardRemoteRepository(snapshot: .empty),
            remoteStatements: remoteStatements ?? StaticStatementRemoteRepository(snapshot: .empty),
            remoteTransactions: remoteTransactions ?? StaticTransactionRemoteRepository(page: .empty),
            remoteImports: remoteImports ?? StaticImportRemoteRepository(batches: []),
            granaAI: granaAI
        )
    }
}
