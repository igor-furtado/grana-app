import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AuthService {
    enum AccessLinkingMethod: Equatable {
        case apple

        var displayName: String {
            switch self {
            case .apple:
                "Apple"
            }
        }
    }

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
        case linkingPrompt(method: AccessLinkingMethod, email: String?)
        case linkingAccess(method: AccessLinkingMethod)
        case failure(String)
    }

    private enum PendingAccessLink {
        case apple(AppleSignInCredentials)

        var method: AccessLinkingMethod {
            switch self {
            case .apple:
                .apple
            }
        }
    }

    private let client: any AuthClientProtocol
    private var pendingAccessLink: PendingAccessLink?

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
        if let session = authenticatedSessionNeedingAppleLinking {
            pendingAccessLink = .apple(credentials)
            loginState = .linkingPrompt(method: .apple, email: session.email)
            return
        }

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
        pendingAccessLink = nil
        loginState = .idle
    }

    func confirmAccessLink() async throws {
        guard let pendingAccessLink else {
            throw AuthFlowError.missingPendingAccessLink
        }

        loginState = .linkingAccess(method: pendingAccessLink.method)
        do {
            let session = try await link(pendingAccessLink)
            state = .authenticated(session)
            self.pendingAccessLink = nil
            loginState = .authenticated
        } catch {
            loginState = .failure(AppErrorPresentation.from(error).message)
            throw error
        }
    }

    func cancelAccessLink() {
        pendingAccessLink = nil
        if case .authenticated = state {
            loginState = .authenticated
        } else {
            loginState = .idle
        }
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

    private func link(_ pendingAccessLink: PendingAccessLink) async throws -> AuthSessionContext {
        switch pendingAccessLink {
        case let .apple(credentials):
            try await client.linkAppleIdentity(credentials)
        }
    }

    private func shouldConfirmAppleLinking(for session: AuthSessionContext) -> Bool {
        !session.providers.contains { $0.caseInsensitiveCompare("apple") == .orderedSame }
    }

    private var authenticatedSessionNeedingAppleLinking: AuthSessionContext? {
        guard case let .authenticated(session) = state,
              shouldConfirmAppleLinking(for: session)
        else {
            return nil
        }
        return session
    }
}
