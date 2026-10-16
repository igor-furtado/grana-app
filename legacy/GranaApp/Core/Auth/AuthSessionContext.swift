import Foundation

struct AuthSessionContext: Equatable {
    let userID: UUID
    let email: String?
    let accessToken: String
    let displayName: String?
    let providers: [String]
    let createdAt: Date?
    let lastSignInAt: Date?
    let emailConfirmedAt: Date?
    let expiresAt: Date?

    nonisolated init(
        userID: UUID,
        email: String?,
        accessToken: String,
        displayName: String? = nil,
        providers: [String] = [],
        createdAt: Date? = nil,
        lastSignInAt: Date? = nil,
        emailConfirmedAt: Date? = nil,
        expiresAt: Date? = nil
    ) {
        self.userID = userID
        self.email = email
        self.accessToken = accessToken
        self.displayName = displayName
        self.providers = providers
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
        self.emailConfirmedAt = emailConfirmedAt
        self.expiresAt = expiresAt
    }
}
