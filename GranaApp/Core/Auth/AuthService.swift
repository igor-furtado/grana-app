import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AuthService {
    enum State: Equatable {
        case restoring
        case unavailable
        case unauthenticated
        case authenticated(AuthSessionContext)
    }

    private let client: any AuthClientProtocol

    private(set) var state: State = .restoring

    init(client: any AuthClientProtocol) {
        self.client = client
    }

    var isAuthenticated: Bool {
        if case .authenticated = state {
            return true
        }
        return false
    }

    func restoreSession() async throws {
        do {
            if let session = try await client.validSession() {
                state = .authenticated(session)
            } else {
                state = .unauthenticated
            }
        } catch {
            if NetworkAvailability.isUnavailable(error) {
                log.network.notice("Falha de rede ao validar sessão remota; exibindo indisponibilidade global.")
                state = .unavailable
                return
            }
            throw error
        }
    }

    func requestMagicLink(email: String) async throws {
        try await client.requestMagicLink(email: email)
    }

    func handleCallback(_ url: URL) async throws {
        let session = try await client.session(from: url)
        state = .authenticated(session)
    }

    func signOut() async throws {
        do {
            try await client.signOut()
        } catch {
            log.network.notice("Auth local nao confirmou logout; estado do app sera encerrado localmente.")
        }
        state = .unauthenticated
    }
}
