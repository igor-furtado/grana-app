import Auth
import Foundation
import PostgREST
import Testing
@testable import GranaAi

@Suite("Sessão autenticada")
struct AuthServiceTests {
    @MainActor
    @Test("Restaura sessão remota válida e fica autenticado")
    func restoresValidRemoteSession() async throws {
        let session = AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-restaurado"
        )
        let authClient = FakeAuthClient(validSession: session)
        let service = AuthService(client: authClient)

        try await service.restoreSession()

        #expect(service.state == .authenticated(session))
    }

    @MainActor
    @Test("Permanece desautenticado quando não existe sessão persistida")
    func staysSignedOutWithoutStoredSession() async throws {
        let authClient = FakeAuthClient(validSession: nil)
        let service = AuthService(client: authClient)

        try await service.restoreSession()

        #expect(service.state == .unauthenticated)
    }

    @MainActor
    @Test("Processa callback do magic link e autentica a sessão")
    func handlesMagicLinkCallback() async throws {
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
        let service = AuthService(client: authClient)

        try await service.handleCallback(callbackURL)

        #expect(service.state == .authenticated(restoredSession))
        #expect(await authClient.handledURL() == callbackURL)
    }

    @MainActor
    @Test("Mostra indisponibilidade global quando a revalidação falha por rede")
    func marksUnavailableWhenRemoteValidationFailsDueToNetwork() async throws {
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
        let service = AuthService(client: authClient)

        try await service.restoreSession()

        #expect(service.state == .unavailable)
    }

    @MainActor
    @Test("Volta para login quando só existe sessão local sem validação remota")
    func ignoresStoredSessionWithoutRemoteValidation() async throws {
        let session = AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-local"
        )
        let authClient = FakeAuthClient(
            validSession: nil,
            storedSession: session
        )
        let service = AuthService(client: authClient)

        try await service.restoreSession()

        #expect(service.state == .unauthenticated)
    }

    @MainActor
    @Test("Encerra a sessão mesmo quando o cliente de auth falha ao sair")
    func signsOutWhenAuthClientFails() async throws {
        let session = AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-local"
        )
        let authClient = FakeAuthClient(
            validSession: session,
            signOutError: URLError(.userAuthenticationRequired)
        )
        let service = AuthService(client: authClient)

        try await service.restoreSession()
        try await service.signOut()

        #expect(service.state == .unauthenticated)
        #expect(await authClient.signOutCallCount() == 1)
    }
}

@Suite("Bootstrap autenticado")
struct AppEnvironmentTests {
    @MainActor
    @Test("Inicializa o perfil uma única vez quando a sessão já está autenticada")
    func ensuresProfileOnceForAuthenticatedSession() async throws {
        let session = AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-local"
        )
        let authClient = FakeAuthClient(validSession: session)
        let bootstrapper = FakeProfileBootstrapper()
        let service = AuthService(client: authClient)
        let environment = AppEnvironment(
            container: .placeholder(),
            authService: service,
            profileBootstrapper: bootstrapper
        )

        try await environment.restoreSessionIfNeeded()
        try await environment.restoreSessionIfNeeded()

        #expect(await bootstrapper.ensureProfileCallCount() == 1)
        #expect(environment.availabilityState == .available)
        #expect(environment.canShowFinancialData == true)
    }

    @MainActor
    @Test("Bloqueia a navegação financeira quando o bootstrap remoto falha por rede")
    func marksUnavailableWhenProfileBootstrapFailsDueToNetwork() async throws {
        let session = AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-local"
        )
        let authClient = FakeAuthClient(validSession: session)
        let bootstrapper = FakeProfileBootstrapper(error: URLError(.cannotConnectToHost))
        let service = AuthService(client: authClient)
        let environment = AppEnvironment(
            container: .placeholder(),
            authService: service,
            profileBootstrapper: bootstrapper
        )

        try await environment.restoreSessionIfNeeded()

        #expect(service.state == .authenticated(session))
        #expect(environment.availabilityState == .unavailable)
        #expect(environment.canShowFinancialData == false)
    }

    @MainActor
    @Test("Volta para login quando o bootstrap remoto rejeita a sessão")
    func returnsToLoginWhenProfileBootstrapRejectsSession() async throws {
        let session = AuthSessionContext(
            userID: UUID(),
            email: "pessoa@exemplo.com",
            accessToken: "jwt-local"
        )
        let authClient = FakeAuthClient(validSession: session)
        let bootstrapper = FakeProfileBootstrapper(error: PostgrestError(
            code: "42501",
            message: "Authentication required"
        ))
        let service = AuthService(client: authClient)
        let environment = AppEnvironment(
            container: .placeholder(),
            authService: service,
            profileBootstrapper: bootstrapper
        )

        try await environment.restoreSessionIfNeeded()

        #expect(service.state == .unauthenticated)
        #expect(environment.availabilityState == .available)
        #expect(environment.canShowFinancialData == false)
    }

    @MainActor
    @Test("Inicializa o perfil após callback mesmo se o boot inicial caiu em login")
    func bootstrapsProfileAfterMagicLinkCallback() async throws {
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
        let bootstrapper = FakeProfileBootstrapper()
        let service = AuthService(client: authClient)
        let environment = AppEnvironment(
            container: .placeholder(),
            authService: service,
            profileBootstrapper: bootstrapper
        )

        try await environment.restoreSessionIfNeeded()
        try await service.handleCallback(callbackURL)
        try await environment.restoreSessionIfNeeded()

        #expect(await bootstrapper.ensureProfileCallCount() == 1)
        #expect(environment.availabilityState == .available)
        #expect(environment.canShowFinancialData == true)
    }
}

@Suite("Dados de perfil da sessão")
struct AuthSessionContextTests {
    @Test("Preserva campos humanos vindos do objeto de autenticação")
    func storesHumanReadableSessionFields() {
        let userID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let lastSignInAt = Date(timeIntervalSince1970: 1_800_003_600)
        let emailConfirmedAt = Date(timeIntervalSince1970: 1_800_000_300)
        let expiresAt = Date(timeIntervalSince1970: 1_800_007_200)

        let session = AuthSessionContext(
            userID: userID,
            email: "pessoa@exemplo.com",
            accessToken: "jwt-atual",
            displayName: "Pessoa Exemplo",
            providers: ["email", "google"],
            createdAt: createdAt,
            lastSignInAt: lastSignInAt,
            emailConfirmedAt: emailConfirmedAt,
            expiresAt: expiresAt
        )

        #expect(session.userID == userID)
        #expect(session.email == "pessoa@exemplo.com")
        #expect(session.displayName == "Pessoa Exemplo")
        #expect(session.providers == ["email", "google"])
        #expect(session.createdAt == createdAt)
        #expect(session.lastSignInAt == lastSignInAt)
        #expect(session.emailConfirmedAt == emailConfirmedAt)
        #expect(session.expiresAt == expiresAt)
    }

    @Test("Mapeia provedores do objeto Session")
    func mapsProvidersFromSupabaseSession() {
        let userID = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let session = Session(
            accessToken: "jwt-atual",
            tokenType: "bearer",
            expiresIn: 3600,
            expiresAt: 1_800_003_600,
            refreshToken: "refresh",
            user: User(
                id: userID,
                appMetadata: ["providers": ["email", "google", " "]],
                userMetadata: [:],
                aud: "authenticated",
                email: "pessoa@exemplo.com",
                createdAt: date,
                updatedAt: date,
                identities: [
                    UserIdentity(
                        id: UUID().uuidString,
                        identityId: UUID(),
                        userId: userID,
                        identityData: [:],
                        provider: "github",
                        createdAt: date,
                        lastSignInAt: date,
                        updatedAt: date
                    ),
                    UserIdentity(
                        id: UUID().uuidString,
                        identityId: UUID(),
                        userId: userID,
                        identityData: [:],
                        provider: "email",
                        createdAt: date,
                        lastSignInAt: date,
                        updatedAt: date
                    ),
                ]
            )
        )

        let context = AuthSessionContext(session: session)

        #expect(context.providers == ["email", "github", "google"])
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

    @Test("Traduz invalid API key para erro de configuração acionável")
    func mapsInvalidAPIKeyToConfigurationError() {
        let mapped = SupabaseAuthClient.normalizedRequestMagicLinkError(
            NSError(domain: "Auth", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Invalid API key",
            ])
        )

        let error = mapped as? AppConfigurationError
        #expect(error == .invalidAPIKey("Config.supabaseAnonKey"))
    }
}

@Suite("Apresentação de erros")
struct AppErrorPresentationTests {
    @Test("Traduz schema api não exposto para erro de configuração")
    func mapsInvalidSchemaToConfigurationError() {
        let presentation = AppErrorPresentation.from(PostgrestError(
            detail: nil,
            hint: "Only the following schemas are exposed: public, graphql_public",
            code: "PGRST106",
            message: "Invalid schema: api"
        ))

        #expect(presentation.title == "Configuração inválida")
        #expect(presentation.message == "Exponha o schema api em Data API > Exposed schemas no projeto Supabase.")
    }
}

private actor FakeAuthClient: AuthClientProtocol {
    private let validSession: AuthSessionContext?
    private let validSessionError: (any Error)?
    private let storedSessionContext: AuthSessionContext?
    private let callbackSession: AuthSessionContext?
    private let signOutError: (any Error)?
    private(set) var lastHandledURL: URL?
    private var signOutCount = 0

    init(
        validSession: AuthSessionContext?,
        validSessionError: (any Error)? = nil,
        storedSession: AuthSessionContext? = nil,
        callbackSession: AuthSessionContext? = nil,
        signOutError: (any Error)? = nil
    ) {
        self.validSession = validSession
        self.validSessionError = validSessionError
        self.storedSessionContext = storedSession ?? validSession
        self.callbackSession = callbackSession ?? validSession
        self.signOutError = signOutError
    }

    func validSession() async throws -> AuthSessionContext? {
        if let validSessionError {
            throw validSessionError
        }
        return validSession
    }

    func storedSession() async -> AuthSessionContext? {
        storedSessionContext
    }

    func requestMagicLink(email _: String) async throws {}

    func session(from callbackURL: URL) async throws -> AuthSessionContext {
        lastHandledURL = callbackURL
        return try #require(callbackSession)
    }

    func signOut() async throws {
        signOutCount += 1
        if let signOutError {
            throw signOutError
        }
    }

    func handledURL() -> URL? {
        lastHandledURL
    }

    func signOutCallCount() -> Int {
        signOutCount
    }
}

private actor FakeProfileBootstrapper: ProfileBootstrapRepositoryProtocol {
    private let error: (any Error)?
    private var callCount = 0

    init(error: (any Error)? = nil) {
        self.error = error
    }

    func ensureProfile() async throws {
        callCount += 1
        if let error {
            throw error
        }
    }

    func ensureProfileCallCount() -> Int {
        callCount
    }
}
