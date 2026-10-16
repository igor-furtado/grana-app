import ComposableArchitecture
import Foundation

struct SupportedInstitutionsClient {
    var load: @Sendable () async throws -> [Institution]

    static func live(container: AppContainer) -> SupportedInstitutionsClient {
        SupportedInstitutionsClient(
            load: {
                try await container.institutionCatalog.load()
            }
        )
    }
}

extension SupportedInstitutionsClient: DependencyKey {
    static let liveValue = SupportedInstitutionsClient(load: { [] })

    static let testValue = SupportedInstitutionsClient(
        load: unimplemented("SupportedInstitutionsClient.load")
    )
}

extension DependencyValues {
    var supportedInstitutionsClient: SupportedInstitutionsClient {
        get { self[SupportedInstitutionsClient.self] }
        set { self[SupportedInstitutionsClient.self] = newValue }
    }
}
