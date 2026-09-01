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

    enum LoginState: Equatable {
        case idle
        case signingInWithApple
        case enteringEmail
        case sendingOTP
        case awaitingOTP(email: String)
        case verifyingOTP(email: String)
        case authenticated
        case linkingPrompt
        case failure(String)
    }

    private let client: any AuthClientProtocol

    private(set) var state: State = .restoring
    private(set) var loginState: LoginState = .idle

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
                loginState = .authenticated
            } else {
                state = .unauthenticated
                loginState = .idle
            }
        } catch {
            if NetworkAvailability.isUnavailable(error) {
                log.network.notice("Falha de rede ao validar sessão remota; exibindo indisponibilidade global.")
                state = .unavailable
                loginState = .idle
                return
            }
            throw error
        }
    }

    func signInWithApple(_ credentials: AppleSignInCredentials) async throws {
        loginState = .signingInWithApple
        do {
            let session = try await client.signInWithApple(credentials)
            state = .authenticated(session)
            loginState = .authenticated
        } catch {
            loginState = .failure(AppErrorPresentation.from(error).message)
            throw error
        }
    }

    func beginEmailEntry() {
        loginState = .enteringEmail
    }

    func resetLoginState() {
        loginState = .idle
    }

    func requestEmailOTP(email: String) async throws {
        loginState = .sendingOTP
        do {
            try await client.requestEmailOTP(email: email)
            loginState = .awaitingOTP(email: email)
        } catch {
            loginState = .failure(AppErrorPresentation.from(error).message)
            throw error
        }
    }

    func verifyEmailOTP(email: String, code: String) async throws {
        loginState = .verifyingOTP(email: email)
        do {
            let session = try await client.verifyEmailOTP(email: email, code: code)
            state = .authenticated(session)
            loginState = .authenticated
        } catch {
            loginState = .failure(AppErrorPresentation.from(error).message)
            throw error
        }
    }

    func handleCallback(_ url: URL) async throws {
        let session = try await client.session(from: url)
        state = .authenticated(session)
        loginState = .authenticated
    }

    func signOut() async throws {
        do {
            try await client.signOut()
        } catch {
            log.network.notice("Auth local nao confirmou logout; estado do app sera encerrado localmente.")
        }
        state = .unauthenticated
        loginState = .idle
    }
}
