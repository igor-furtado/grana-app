import Foundation

protocol AuthClientProtocol: Sendable {
    func validSession() async throws -> AuthSessionContext?
    func storedSession() async -> AuthSessionContext?
    func requestMagicLink(email: String) async throws
    func session(from callbackURL: URL) async throws -> AuthSessionContext
    func signOut() async throws
}
