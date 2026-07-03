import Foundation

struct AuthSessionContext: Equatable, Sendable {
    let userID: UUID
    let email: String?
    let accessToken: String

    nonisolated init(
        userID: UUID,
        email: String?,
        accessToken: String
    ) {
        self.userID = userID
        self.email = email
        self.accessToken = accessToken
    }
}
