import Foundation

struct AppleSignInCredentials: Equatable {
    let identityToken: String
    let authorizationCode: String?
    let fullName: String?
    let nonce: String?
}

protocol AuthClientProtocol: Sendable {
    func validSession() async throws -> AuthSessionContext?
    func storedSession() async -> AuthSessionContext?
    func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthSessionContext
    func linkAppleIdentity(_ credentials: AppleSignInCredentials) async throws -> AuthSessionContext
    func requestEmailOTP(email: String) async throws
    func verifyEmailOTP(email: String, code: String) async throws -> AuthSessionContext
    func session(from callbackURL: URL) async throws -> AuthSessionContext
    func signOut() async throws
}
