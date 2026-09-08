import ComposableArchitecture
import Foundation

struct ImportTriageClient {
    var reloadOFXResolution: @Sendable (_ resolution: OFXStatementResolution, _ accountId: UUID?) async
        -> OFXStatementResolution
    var reloadCSVResolution: @Sendable (_ resolution: CSVStatementResolution, _ accountId: UUID?) async
        -> CSVStatementResolution

    static func live(container: AppContainer) -> ImportTriageClient {
        ImportTriageClient(
            reloadOFXResolution: { resolution, accountId in
                await ImportDuplicateResolution.reloadOFXResolution(
                    resolution,
                    accountId: accountId,
                    remoteTransactions: container.remoteTransactions
                )
            },
            reloadCSVResolution: { resolution, accountId in
                await ImportDuplicateResolution.reloadCSVResolution(
                    resolution,
                    accountId: accountId,
                    remoteTransactions: container.remoteTransactions
                )
            }
        )
    }
}

extension ImportTriageClient: DependencyKey {
    static let liveValue = ImportTriageClient(
        reloadOFXResolution: { resolution, _ in resolution },
        reloadCSVResolution: { resolution, _ in resolution }
    )

    static let testValue = ImportTriageClient(
        reloadOFXResolution: { _, _ in
            fatalError("ImportTriageClient.reloadOFXResolution")
        },
        reloadCSVResolution: { _, _ in
            fatalError("ImportTriageClient.reloadCSVResolution")
        }
    )
}

extension DependencyValues {
    var importTriageClient: ImportTriageClient {
        get { self[ImportTriageClient.self] }
        set { self[ImportTriageClient.self] = newValue }
    }
}
