import OSLog
import SwiftUI

@main
struct GranaAiApp: App {
    @State private var environment: AppEnvironment

    init() {
        let env = AppEnvironment()
        _environment = State(initialValue: env)
        log.database.info("AppEnvironment inicializado com sucesso")

        // Limpeza one-shot: versões anteriores persistiam o tema em
        // `appColorScheme` via `@AppStorage`. O override hoje é por sessão
        // (não persistido), então a chave fica órfã pra quem atualizou.
        // Remoção é idempotente — se não existir, é no-op.
        UserDefaults.standard.removeObject(forKey: "appColorScheme")
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
        // Tamanho default na primeira abertura — gabarito do app. Mínimo
        // efetivo vem do `.frame(minWidth:minHeight:)` no `ContentView`;
        // `.windowResizability(.contentSize)` faz o AppKit respeitar isso.
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentSize)
    }
}
