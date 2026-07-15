import Foundation
import PowerSync
import PostgREST
import Testing
@testable import GranaAi

@Suite("Sessão autenticada")
struct AuthServiceTests {
    @MainActor
    @Test("Restaura sessão persistida e inicia o sync")
    func restoresStoredSessionAndStartsSync() async throws {
        let session = AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-restaurado"
        )
        let authClient = FakeAuthClient(validSession: session)
        let syncCoordinator = FakeSyncCoordinator()
        let service = AuthService(
            client: authClient,
            syncCoordinator: syncCoordinator
        )

        try await service.restoreSession()

        #expect(service.state == .authenticated(session))
        #expect(syncCoordinator.connectCallCount == 1)
        #expect(service.syncIssueMessage == nil)
    }

    @MainActor
    @Test("Permanece desautenticado quando não existe sessão persistida")
    func staysSignedOutWithoutStoredSession() async throws {
        let authClient = FakeAuthClient(validSession: nil)
        let syncCoordinator = FakeSyncCoordinator()
        let service = AuthService(
            client: authClient,
            syncCoordinator: syncCoordinator
        )

        try await service.restoreSession()

        #expect(service.state == .unauthenticated)
        #expect(syncCoordinator.connectCallCount == 0)
    }

    @MainActor
    @Test("Processa callback do magic link e inicia o sync")
    func handlesMagicLinkCallbackAndStartsSync() async throws {
        let callbackURL = try #require(URL(string: "com.igorfurtado.GranaAi://auth-callback?code=abc"))
        let restoredSession = AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-callback"
        )
        let authClient = FakeAuthClient(
            validSession: nil,
            callbackSession: restoredSession
        )
        let syncCoordinator = FakeSyncCoordinator()
        let service = AuthService(
            client: authClient,
            syncCoordinator: syncCoordinator
        )

        try await service.handleCallback(callbackURL)

        #expect(service.state == .authenticated(restoredSession))
        #expect(syncCoordinator.connectCallCount == 1)
        #expect(await authClient.handledURL() == callbackURL)
    }

    @MainActor
    @Test("Mantem sessao autenticada quando o sync remoto falha no restore")
    func keepsAuthenticatedStateWhenSyncFailsDuringRestore() async throws {
        let session = AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-restaurado"
        )
        let authClient = FakeAuthClient(validSession: session)
        let syncCoordinator = FakeSyncCoordinator(connectError: URLError(.cannotConnectToHost))
        let service = AuthService(
            client: authClient,
            syncCoordinator: syncCoordinator
        )

        try await service.restoreSession()

        #expect(service.state == .authenticated(session))
        #expect(syncCoordinator.connectCallCount == 1)
        #expect(service.syncIssueMessage != nil)
    }

    @MainActor
    @Test("Usa sessao local armazenada quando a revalidacao remota falha")
    func fallsBackToStoredSessionWhenRemoteValidationFails() async throws {
        let session = AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-local"
        )
        let authClient = FakeAuthClient(
            validSession: nil,
            validSessionError: URLError(.networkConnectionLost),
            storedSession: session
        )
        let syncCoordinator = FakeSyncCoordinator(connectError: URLError(.cannotConnectToHost))
        let service = AuthService(
            client: authClient,
            syncCoordinator: syncCoordinator
        )

        try await service.restoreSession()

        #expect(service.state == .authenticated(session))
        #expect(syncCoordinator.connectCallCount == 1)
        #expect(service.syncIssueMessage != nil)
    }
}

@Suite("Credenciais PowerSync")
struct SupabaseConnectorTests {
    private func makeDatabase() -> any PowerSyncDatabaseProtocol {
        PowerSyncDatabase(
            schema: appSchema,
            dbFilename: ":memory:",
            logger: DefaultLogger()
        )
    }

    @Test("Usa o JWT atual do Supabase como credencial canônica")
    func fetchesPowerSyncCredentialsFromSupabaseSession() async throws {
        let authClient = FakeAuthClient(validSession: AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-atual"
        ))
        let connector = SupabaseConnector(
            authClient: authClient,
            powerSyncURL: "https://example.powersync.app"
        )

        let credentials = try #require(try await connector.fetchCredentials())

        #expect(credentials.endpoint == "https://example.powersync.app")
        #expect(credentials.token == "jwt-atual")
    }

    @Test("Falha cedo quando a URL do PowerSync ainda está com placeholder")
    func rejectsPlaceholderPowerSyncURL() async throws {
        let authClient = FakeAuthClient(validSession: AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-atual"
        ))
        let connector = SupabaseConnector(
            authClient: authClient,
            powerSyncURL: "https://YOUR_INSTANCE.powersync.journeyapps.com"
        )

        await #expect(throws: AppConfigurationError.self) {
            _ = try await connector.fetchCredentials()
        }
    }

    @Test("Envia CRUD sincronizável com user_id e remove da fila local")
    func uploadsSyncedRowsAndCompletesLocalTransaction() async throws {
        let db = makeDatabase()
        let accountID = UUID()
        let userID = UUID()
        let now = Date()
        let authClient = FakeAuthClient(validSession: AuthSessionContext(
            userID: userID,
            email: "pessoa@exemplo.com",
            accessToken: "jwt-atual"
        ))
        let remoteStore = FakeSyncRemoteStore()
        let connector = SupabaseConnector(
            authClient: authClient,
            powerSyncURL: "https://example.powersync.app",
            remoteStore: remoteStore
        )

        try await db.writeTransaction { tx in
            try tx.execute(
                sql: """
                INSERT INTO accounts (
                    id,
                    type,
                    initial_balance_cents,
                    archived,
                    institution_id,
                    currency,
                    created_at,
                    updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                parameters: [
                    accountID.uuidString,
                    AccountType.checking.rawValue,
                    1234,
                    0,
                    nil,
                    "BRL",
                    Converters.dateToString(now),
                    Converters.dateToString(now),
                ]
            )
        }

        try await connector.uploadData(database: db)

        let operations = await remoteStore.operations()
        #expect(operations.count == 1)
        #expect(operations[0].kind == .upsert)
        #expect(operations[0].table == "accounts")
        #expect(operations[0].row?["id"] == accountID.uuidString.lowercased())
        #expect(operations[0].row?["user_id"] == userID.uuidString.lowercased())

        try await connector.uploadData(database: db)
        #expect(await remoteStore.operations().count == 1)

        try await db.close()
    }

    @Test("Ignora tabelas locais que não fazem parte do sync remoto")
    func ignoresLocalOnlyTables() async throws {
        let db = makeDatabase()
        let authClient = FakeAuthClient(validSession: AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-atual"
        ))
        let remoteStore = FakeSyncRemoteStore()
        let connector = SupabaseConnector(
            authClient: authClient,
            powerSyncURL: "https://example.powersync.app",
            remoteStore: remoteStore
        )

        try await db.writeTransaction { tx in
            try tx.execute(
                sql: """
                INSERT INTO categories (
                    id,
                    parent_id,
                    name,
                    kind,
                    slug,
                    created_at
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                parameters: [
                    UUID().uuidString,
                    nil,
                    "Local",
                    CategoryKind.expense.rawValue,
                    "local",
                    Converters.dateToString(Date()),
                ]
            )
        }

        try await connector.uploadData(database: db)

        #expect(await remoteStore.operations().isEmpty)

        try await db.close()
    }

    @Test("Descarta transação quando o backend devolve erro fatal")
    func discardsTransactionOnFatalRemoteError() async throws {
        let db = makeDatabase()
        let authClient = FakeAuthClient(validSession: AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-atual"
        ))
        let remoteStore = FakeSyncRemoteStore()
        await remoteStore.enqueueError(PostgrestError(
            code: "23505",
            message: "duplicate key"
        ))
        let connector = SupabaseConnector(
            authClient: authClient,
            powerSyncURL: "https://example.powersync.app",
            remoteStore: remoteStore
        )

        try await db.writeTransaction { tx in
            try tx.execute(
                sql: """
                INSERT INTO accounts (
                    id,
                    type,
                    initial_balance_cents,
                    archived,
                    institution_id,
                    currency,
                    created_at,
                    updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                parameters: [
                    UUID().uuidString,
                    AccountType.checking.rawValue,
                    100,
                    0,
                    nil,
                    "BRL",
                    Converters.dateToString(Date()),
                    Converters.dateToString(Date()),
                ]
            )
        }

        try await connector.uploadData(database: db)
        try await connector.uploadData(database: db)

        #expect(await remoteStore.operations().count == 1)

        try await db.close()
    }

    @Test("Mantém transação pendente para retry em erro transitório")
    func retriesTransactionAfterTransientRemoteError() async throws {
        let db = makeDatabase()
        let authClient = FakeAuthClient(validSession: AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-atual"
        ))
        let remoteStore = FakeSyncRemoteStore()
        await remoteStore.enqueueError(URLError(.networkConnectionLost))
        let connector = SupabaseConnector(
            authClient: authClient,
            powerSyncURL: "https://example.powersync.app",
            remoteStore: remoteStore
        )

        try await db.writeTransaction { tx in
            try tx.execute(
                sql: """
                INSERT INTO accounts (
                    id,
                    type,
                    initial_balance_cents,
                    archived,
                    institution_id,
                    currency,
                    created_at,
                    updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                parameters: [
                    UUID().uuidString,
                    AccountType.checking.rawValue,
                    100,
                    0,
                    nil,
                    "BRL",
                    Converters.dateToString(Date()),
                    Converters.dateToString(Date()),
                ]
            )
        }

        await #expect(throws: URLError.self) {
            try await connector.uploadData(database: db)
        }

        try await connector.uploadData(database: db)

        #expect(await remoteStore.operations().count == 2)

        try await db.close()
    }
}

@Suite("Configuração do Supabase Auth")
struct SupabaseAuthClientTests {
    @Test("Falha cedo quando a URL do Supabase ainda está com placeholder")
    func rejectsPlaceholderSupabaseURLBeforeNetwork() async throws {
        let client = SupabaseAuthClient(
            supabaseURL: "https://YOUR_PROJECT.supabase.co",
            supabaseAnonKey: "sb_publishable_xpto"
        )

        await #expect(throws: AppConfigurationError.self) {
            try await client.requestMagicLink(email: "pessoa@exemplo.com")
        }
    }

    @Test("Falha cedo quando a anon key do Supabase ainda está com placeholder")
    func rejectsPlaceholderSupabaseAnonKeyBeforeNetwork() async throws {
        let client = SupabaseAuthClient(
            supabaseURL: "https://abcxyzcompany.supabase.co",
            supabaseAnonKey: "YOUR_ANON_KEY"
        )

        await #expect(throws: AppConfigurationError.self) {
            try await client.requestMagicLink(email: "pessoa@exemplo.com")
        }
    }
}

private actor FakeAuthClient: AuthClientProtocol {
    private let validSession: AuthSessionContext?
    private let validSessionError: (any Error)?
    private let storedSessionContext: AuthSessionContext?
    private let callbackSession: AuthSessionContext?
    private(set) var lastHandledURL: URL?

    init(
        validSession: AuthSessionContext?,
        validSessionError: (any Error)? = nil,
        storedSession: AuthSessionContext? = nil,
        callbackSession: AuthSessionContext? = nil
    ) {
        self.validSession = validSession
        self.validSessionError = validSessionError
        storedSessionContext = storedSession ?? validSession
        self.callbackSession = callbackSession ?? validSession
    }

    func validSession() async throws -> AuthSessionContext? {
        if let validSessionError {
            throw validSessionError
        }
        return validSession
    }

    func storedSession() async -> AuthSessionContext? {
        return storedSessionContext
    }

    func requestMagicLink(email _: String) async throws {}

    func session(from callbackURL: URL) async throws -> AuthSessionContext {
        lastHandledURL = callbackURL
        return try #require(callbackSession)
    }

    func handledURL() -> URL? {
        lastHandledURL
    }
}

private actor FakeSyncRemoteStore: SyncRemoteStore {
    struct Operation: Equatable {
        enum Kind: Equatable {
            case upsert
            case update
            case delete
        }

        let kind: Kind
        let table: String
        let row: [String: String?]?
        let id: String?
        let userID: String?
    }

    private var pendingErrors: [any Error] = []
    private var recordedOperations: [Operation] = []

    func enqueueError(_ error: any Error) {
        pendingErrors.append(error)
    }

    func upsert(table: String, row: [String: String?]) async throws {
        recordedOperations.append(.init(
            kind: .upsert,
            table: table,
            row: row,
            id: nil,
            userID: nil
        ))
        if !pendingErrors.isEmpty {
            throw pendingErrors.removeFirst()
        }
    }

    func update(
        table: String,
        id: String,
        userID: String,
        values: [String: String?]
    ) async throws {
        recordedOperations.append(.init(
            kind: .update,
            table: table,
            row: values,
            id: id,
            userID: userID
        ))
        if !pendingErrors.isEmpty {
            throw pendingErrors.removeFirst()
        }
    }

    func delete(table: String, id: String, userID: String) async throws {
        recordedOperations.append(.init(
            kind: .delete,
            table: table,
            row: nil,
            id: id,
            userID: userID
        ))
        if !pendingErrors.isEmpty {
            throw pendingErrors.removeFirst()
        }
    }

    func operations() -> [Operation] {
        recordedOperations
    }
}

@MainActor
private final class FakeSyncCoordinator: SyncCoordinatorProtocol {
    private(set) var connectCallCount = 0
    private let connectError: (any Error)?

    init(connectError: (any Error)? = nil) {
        self.connectError = connectError
    }

    func connect() async throws {
        connectCallCount += 1
        if let connectError {
            throw connectError
        }
    }
}
