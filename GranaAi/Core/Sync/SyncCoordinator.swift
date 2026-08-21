import Foundation
import PowerSync

@MainActor
protocol SyncCoordinatorProtocol: AnyObject {
    func connect() async throws
    func disconnect() async throws
}

@MainActor
final class SyncCoordinator: SyncCoordinatorProtocol {
    private let container: AppContainer
    private let connector: any PowerSyncBackendConnectorProtocol

    init(
        container: AppContainer,
        connector: any PowerSyncBackendConnectorProtocol
    ) {
        self.container = container
        self.connector = connector
    }

    func connect() async throws {
        try await container.connectSync(connector: connector)
    }

    func disconnect() async throws {
        try await container.disconnectSync()
    }
}
