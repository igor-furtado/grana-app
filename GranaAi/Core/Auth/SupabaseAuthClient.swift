import Auth
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

    nonisolated private static func makeClient(
        supabaseURL: String,
        supabaseAnonKey: String
    ) throws -> SupabaseClient {
        let validatedURL = try AppConfigurationValidator.supabaseURL(supabaseURL)
        let validatedAnonKey = try AppConfigurationValidator.supabaseAnonKey(supabaseAnonKey)
        let options = SupabaseClientOptions(auth: .init(
            redirectToURL: AuthCallback.redirectURL
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
            return AuthSessionContext(session: try await client.auth.session)
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

    func requestMagicLink(email: String) async throws {
        let client = try resolvedClient()
        try await client.auth.signInWithOTP(
            email: email,
            redirectTo: AuthCallback.redirectURL
        )
    }

    func session(from callbackURL: URL) async throws -> AuthSessionContext {
        let client = try resolvedClient()
        return AuthSessionContext(
            session: try await client.auth.session(from: callbackURL)
        )
    }
}

private extension AuthSessionContext {
    nonisolated init(session: Session) {
        self.init(
            userID: session.user.id,
            email: session.user.email,
            accessToken: session.accessToken
        )
    }
}
