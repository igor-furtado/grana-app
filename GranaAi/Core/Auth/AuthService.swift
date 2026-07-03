import Foundation
import Observation

@MainActor
@Observable
final class AuthService {
    enum State: Equatable {
        case restoring
        case unauthenticated
        case authenticated(AuthSessionContext)
    }

    private let client: any AuthClientProtocol
    private let syncCoordinator: any SyncCoordinatorProtocol

    private(set) var state: State = .restoring

    init(
        client: any AuthClientProtocol,
        syncCoordinator: any SyncCoordinatorProtocol
    ) {
        self.client = client
        self.syncCoordinator = syncCoordinator
    }

    var isAuthenticated: Bool {
        if case .authenticated = state {
            return true
        }
        return false
    }

    func restoreSession() async throws {
        if let session = try await client.validSession() {
            state = .authenticated(session)
            try await syncCoordinator.connect()
        } else {
            state = .unauthenticated
        }
    }

    func requestMagicLink(email: String) async throws {
        try await client.requestMagicLink(email: email)
    }

    func handleCallback(_ url: URL) async throws {
        let session = try await client.session(from: url)
        state = .authenticated(session)
        try await syncCoordinator.connect()
    }
}
