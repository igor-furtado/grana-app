import Foundation
import Supabase

enum SupabaseAuthenticatedClientFactory {
    nonisolated static func makeClient(
        authClient: any AuthClientProtocol,
        supabaseURL: String,
        supabaseAnonKey: String
    ) throws -> SupabaseClient {
        let validatedURL = try AppConfigurationValidator.supabaseURL(supabaseURL)
        let validatedAnonKey = try AppConfigurationValidator.supabaseAnonKey(supabaseAnonKey)
        return SupabaseClient(
            supabaseURL: validatedURL,
            supabaseKey: validatedAnonKey,
            options: SupabaseClientOptions(auth: .init(
                accessToken: { [authClient] in
                    try await authClient.validSession()?.accessToken
                }
            ))
        )
    }
}
