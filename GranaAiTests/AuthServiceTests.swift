import Foundation
import PowerSync
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
}

@Suite("Credenciais PowerSync")
struct SupabaseConnectorTests {
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
    private let callbackSession: AuthSessionContext?
    private(set) var lastHandledURL: URL?

    init(
        validSession: AuthSessionContext?,
        callbackSession: AuthSessionContext? = nil
    ) {
        self.validSession = validSession
        self.callbackSession = callbackSession ?? validSession
    }

    func validSession() async throws -> AuthSessionContext? {
        validSession
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

@MainActor
private final class FakeSyncCoordinator: SyncCoordinatorProtocol {
    private(set) var connectCallCount = 0

    func connect() async throws {
        connectCallCount += 1
    }
}
