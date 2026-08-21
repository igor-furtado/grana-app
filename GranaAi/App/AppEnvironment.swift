import Foundation

@MainActor
@Observable
final class AppEnvironment {
    enum AvailabilityState: Equatable {
        case available
        case unavailable
    }

    let container: AppContainer
    let authService: AuthService
    let setupError: Error?

    private let profileBootstrapper: any ProfileBootstrapRepositoryProtocol
    private var hasRestoredSession = false
    private var hasInitializedProfile = false

    private(set) var availabilityState: AvailabilityState = .available

    convenience init() {
        let authClient = SupabaseAuthClient()
        let container = AppContainer.setup(authClient: authClient)
        let authService = AuthService(client: authClient)
        let profileBootstrapper = SupabaseProfileBootstrapRepository(authClient: authClient)

        self.init(
            container: container,
            authService: authService,
            profileBootstrapper: profileBootstrapper
        )
    }

    init(
        container: AppContainer,
        authService: AuthService,
        profileBootstrapper: any ProfileBootstrapRepositoryProtocol,
        error: Error? = nil
    ) {
        self.container = container
        self.authService = authService
        self.profileBootstrapper = profileBootstrapper
        self.setupError = error
    }

    var canShowFinancialData: Bool {
        availabilityState == .available && authService.isAuthenticated
    }

    func restoreSessionIfNeeded() async throws {
        if !hasRestoredSession {
            hasRestoredSession = true
            try await authService.restoreSession()
        }

        try await ensureAuthenticatedProfileIfNeeded()
    }

    func retryStartup() async throws {
        availabilityState = .available
        hasRestoredSession = false
        hasInitializedProfile = false
        try await restoreSessionIfNeeded()
    }

    private func ensureAuthenticatedProfileIfNeeded() async throws {
        switch authService.state {
        case .restoring:
            return
        case .unavailable:
            availabilityState = .unavailable
            hasInitializedProfile = false
        case .unauthenticated:
            availabilityState = .available
            hasInitializedProfile = false
        case .authenticated:
            guard !hasInitializedProfile else {
                availabilityState = .available
                return
            }

            do {
                try await profileBootstrapper.ensureProfile()
                hasInitializedProfile = true
                availabilityState = .available
            } catch {
                if NetworkAvailability.isUnavailable(error) {
                    availabilityState = .unavailable
                    return
                }
                if RemoteSessionFailure.requiresLogin(error) {
                    hasInitializedProfile = false
                    availabilityState = .available
                    try await authService.signOut()
                    return
                }
                throw error
            }
        }
    }
}
