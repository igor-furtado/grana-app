import OSLog
import SwiftUI

@main
struct GranaAppApp: App {
    @State private var environment: AppEnvironment

    init() {
        let env = AppEnvironment()
        _environment = State(initialValue: env)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
                .onOpenURL { url in
                    Task {
                        do {
                            try await environment.authService.handleCallback(url)
                            try await environment.restoreSessionIfNeeded()
                        } catch {
                            NoticeCenter.shared.report(
                                error,
                                title: "Falha ao concluir login"
                            )
                        }
                    }
                }
                .task {
                    do {
                        try await environment.restoreSessionIfNeeded()
                    } catch {
                        NoticeCenter.shared.report(error, title: "Falha ao iniciar o app")
                    }
                    if let setupError = environment.setupError {
                        NoticeCenter.shared.report(setupError, title: "Falha ao iniciar o banco")
                    }
                }
        }
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentSize)
    }
}
