import Foundation
import PowerSync

final class SupabaseConnector: PowerSyncBackendConnectorProtocol {
    private let authClient: any AuthClientProtocol
    private let powerSyncURL: String

    init(
        authClient: any AuthClientProtocol,
        powerSyncURL: String = Config.powerSyncURL
    ) {
        self.authClient = authClient
        self.powerSyncURL = powerSyncURL
    }

    func fetchCredentials() async throws -> PowerSyncCredentials? {
        guard let session = try await authClient.validSession() else {
            return nil
        }
        return PowerSyncCredentials(
            endpoint: try AppConfigurationValidator.powerSyncURL(powerSyncURL),
            token: session.accessToken
        )
    }

    func uploadData(database _: PowerSyncDatabaseProtocol) async throws {}
}
