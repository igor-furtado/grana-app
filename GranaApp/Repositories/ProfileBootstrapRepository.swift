import Foundation
import Supabase

protocol ProfileBootstrapRepositoryProtocol: Sendable {
    func ensureProfile() async throws
}

actor SupabaseProfileBootstrapRepository: ProfileBootstrapRepositoryProtocol {
    private let authClient: any AuthClientProtocol
    private let supabaseURL: String
    private let supabaseAnonKey: String
    private var client: SupabaseClient?

    init(
        authClient: any AuthClientProtocol,
        supabaseURL: String? = nil,
        supabaseAnonKey: String? = nil
    ) {
        self.authClient = authClient
        self.supabaseURL = supabaseURL ?? Config.supabaseURL
        self.supabaseAnonKey = supabaseAnonKey ?? Config.supabaseAnonKey
    }

    func ensureProfile() async throws {
        let client = try resolvedClient()
        try await client
            .schema("api")
            .rpc("v1_ensure_profile")
            .execute()
    }

    private func resolvedClient() throws -> SupabaseClient {
        if let client {
            return client
        }

        let client = try SupabaseAuthenticatedClientFactory.makeClient(
            authClient: authClient,
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey
        )
        self.client = client
        return client
    }
}
