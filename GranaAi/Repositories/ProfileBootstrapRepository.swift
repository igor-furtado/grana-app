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

        let validatedURL = try AppConfigurationValidator.supabaseURL(supabaseURL)
        let validatedAnonKey = try AppConfigurationValidator.supabaseAnonKey(supabaseAnonKey)
        let client = SupabaseClient(
            supabaseURL: validatedURL,
            supabaseKey: validatedAnonKey,
            options: SupabaseClientOptions(auth: .init(
                accessToken: { [authClient] in
                    try await authClient.validSession()?.accessToken
                }
            ))
        )
        self.client = client
        return client
    }
}
