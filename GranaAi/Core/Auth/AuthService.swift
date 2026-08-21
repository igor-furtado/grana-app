import Foundation
import Observation
import OSLog

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
    private(set) var syncIssueMessage: String?

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
        let session: AuthSessionContext?
        do {
            session = try await client.validSession()
        } catch {
            guard let storedSession = await client.storedSession() else {
                throw error
            }
            log.sync.notice("Falha ao revalidar sessão remota; mantendo sessão local em modo degradado.")
            state = .authenticated(storedSession)
            await connectBestEffort()
            return
        }

        if let session {
            state = .authenticated(session)
            await connectBestEffort()
        } else {
            syncIssueMessage = nil
            state = .unauthenticated
        }
    }

    func requestMagicLink(email: String) async throws {
        try await client.requestMagicLink(email: email)
    }

    func handleCallback(_ url: URL) async throws {
        let session = try await client.session(from: url)
        state = .authenticated(session)
        await connectBestEffort()
    }

    func signOut() async throws {
        do {
            try await client.signOut()
        } catch {
            log.sync.notice("Auth local nao confirmou logout; estado do app sera encerrado localmente.")
        }
        do {
            try await syncCoordinator.disconnect()
        } catch {
            log.sync.notice("PowerSync nao desconectou durante logout; sessão local foi encerrada.")
        }
        syncIssueMessage = nil
        state = .unauthenticated
    }

    private func connectBestEffort() async {
        do {
            try await syncCoordinator.connect()
            syncIssueMessage = nil
        } catch {
            log.sync.error("Falha ao iniciar sync autenticado; app seguirá em modo local-first.")
            syncIssueMessage = """
            Nao foi possivel conectar ao sync agora. \
            O app continua usando os dados locais e tentara sincronizar novamente na proxima abertura.
            """
        }
    }
}
