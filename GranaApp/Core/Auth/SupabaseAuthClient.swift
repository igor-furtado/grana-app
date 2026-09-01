import Foundation
import Supabase

actor SupabaseAuthClient: AuthClientProtocol {
    private let client: SupabaseClient?
    private let supabaseURL: String
    private let supabaseAnonKey: String

    init() {
        self.client = nil
        self.supabaseURL = Config.supabaseURL
        self.supabaseAnonKey = Config.supabaseAnonKey
    }

    init(
        client: SupabaseClient? = nil,
        supabaseURL: String,
        supabaseAnonKey: String
    ) {
        self.client = client
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
    }

    private func resolvedClient() throws -> SupabaseClient {
        if let client {
            return client
        }
        return try Self.makeClient(
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey
        )
    }

    private nonisolated static func makeClient(
        supabaseURL: String,
        supabaseAnonKey: String
    ) throws -> SupabaseClient {
        let validatedURL = try AppConfigurationValidator.supabaseURL(supabaseURL)
        let validatedAnonKey = try AppConfigurationValidator.supabaseAnonKey(supabaseAnonKey)
        let options = SupabaseClientOptions(auth: .init(
            redirectToURL: AuthCallback.redirectURL,
            emitLocalSessionAsInitialSession: true
        ))
        return SupabaseClient(
            supabaseURL: validatedURL,
            supabaseKey: validatedAnonKey,
            options: options
        )
    }

    func validSession() async throws -> AuthSessionContext? {
        let client = try resolvedClient()
        do {
            return try AuthSessionContext(session: await client.auth.session)
        } catch AuthError.sessionMissing {
            return nil
        }
    }

    func storedSession() async -> AuthSessionContext? {
        guard let client = try? resolvedClient(),
              let session = client.auth.currentSession
        else {
            return nil
        }
        return AuthSessionContext(session: session)
    }

    func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthSessionContext {
        let client = try resolvedClient()
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: credentials.identityToken,
                    nonce: credentials.nonce
                )
            )

            return AuthSessionContext(session: session)
        } catch {
            throw Self.normalizedAuthRequestError(error)
        }
    }

    func requestEmailOTP(email: String) async throws {
        let client = try resolvedClient()
        do {
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: AuthCallback.redirectURL
            )
        } catch {
            throw Self.normalizedAuthRequestError(error)
        }
    }

    func verifyEmailOTP(email: String, code: String) async throws -> AuthSessionContext {
        let client = try resolvedClient()
        do {
            let response = try await client.auth.verifyOTP(
                email: email,
                token: code,
                type: .email,
                redirectTo: AuthCallback.redirectURL
            )
            guard let session = response.session else {
                throw AuthFlowError.missingSessionAfterVerification
            }
            return AuthSessionContext(session: session)
        } catch {
            throw Self.normalizedAuthRequestError(error)
        }
    }

    func session(from callbackURL: URL) async throws -> AuthSessionContext {
        let client = try resolvedClient()
        return try AuthSessionContext(
            session: await client.auth.session(from: callbackURL)
        )
    }

    func signOut() async throws {
        let client = try resolvedClient()
        try await client.auth.signOut(scope: .local)
    }

    nonisolated static func normalizedAuthRequestError(_ error: any Error) -> any Error {
        let message = (error as NSError).localizedDescription
        if message.localizedCaseInsensitiveContains("Invalid API key") {
            return AppConfigurationError.invalidAPIKey("Config.supabaseAnonKey")
        }
        return error
    }
}

enum AuthFlowError: LocalizedError, Equatable {
    case missingSessionAfterVerification

    var errorDescription: String? {
        switch self {
        case .missingSessionAfterVerification:
            "O código foi verificado, mas o servidor não retornou uma sessão ativa."
        }
    }
}

extension AuthSessionContext {
    nonisolated init(session: Session) {
        self.init(
            userID: session.user.id,
            email: session.user.email,
            accessToken: session.accessToken,
            displayName: Self.displayName(from: session.user.userMetadata),
            providers: Self.providers(from: session),
            createdAt: session.user.createdAt,
            lastSignInAt: session.user.lastSignInAt,
            emailConfirmedAt: session.user.emailConfirmedAt,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }

    private nonisolated static func displayName(from metadata: [String: AnyJSON]) -> String? {
        for key in ["display_name", "name", "full_name"] {
            guard let value = metadata[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else { continue }
            return value
        }
        return nil
    }

    private nonisolated static func providers(from session: Session) -> [String] {
        let identityProviders = session.user.identities?.map(\.provider) ?? []
        let metadataProviders = providers(from: session.user.appMetadata["providers"])
        let providers = identityProviders + metadataProviders

        return Array(Set(providers.compactMap(normalizedProvider(_:)))).sorted()
    }

    private nonisolated static func providers(from metadata: AnyJSON?) -> [String] {
        if let provider = metadata?.stringValue {
            return [provider]
        }
        return metadata?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    private nonisolated static func normalizedProvider(_ provider: String) -> String? {
        let value = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return value
    }
}
