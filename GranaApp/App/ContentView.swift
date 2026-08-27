import SwiftUI

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment

    /// Restaurado entre sessões via `@SceneStorage` — abrir o app cai na
    /// última seção visitada (UX padrão macOS). `rawValue: String` é o que o
    /// SceneStorage persiste; reconstruímos o `AppSection` no getter abaixo.
    /// Default `.dashboard` cobre o primeiro lançamento + casos de raw value
    /// inválido (ex: enum mudou entre versões).
    @SceneStorage("ContentView.selection") private var selectionRaw: String = AppSection.dashboard.rawValue

    private var selection: AppSection {
        AppSection(rawValue: selectionRaw) ?? .dashboard
    }

    var body: some View {
        Group {
            if environment.availabilityState == .unavailable {
                unavailableContent
            } else {
                switch environment.authService.state {
                case .restoring:
                    restoringContent
                case .unavailable:
                    unavailableContent
                case .unauthenticated:
                    LoginView(authService: environment.authService)
                case .authenticated:
                    authenticatedContent
                }
            }
        }
        .preferredColorScheme(.light)
        .noticeOverlay()
    }

    private var restoringContent: some View {
        ZStack {
            GranaBackground()
            ProgressView("Restaurando sessão…")
                .foregroundStyle(GranaTheme.Palette.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unavailableContent: some View {
        ZStack {
            GranaBackground()
            EmptyStateView(
                "GranaApp indisponível",
                icon: .sidebarDashboard,
                description: "Não foi possível falar com o backend agora. Tente novamente para validar a sessão e carregar os dados financeiros."
            ) {
                Button("Tentar novamente") {
                    Task {
                        do {
                            try await environment.retryStartup()
                        } catch {
                            NoticeCenter.shared.report(error, title: "Falha ao tentar novamente")
                        }
                    }
                }
                .buttonStyle(GranaPrimaryButtonStyle())
            }
            .padding(GranaTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var authenticatedContent: some View {
        ZStack {
            GranaBackground()
            HStack {
                AppNavigationRail(selection: selection) { section in
                    selectionRaw = section.rawValue
                }
                .padding(GranaTheme.Layout.railInsets)

                NavigationStack {
                    selectedSectionView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }    
            .padding(GranaTheme.Layout.pageInsets)

        }
        .onReceive(NotificationCenter.default.publisher(for: .appSectionNavigationRequested)) { notification in
            guard let rawValue = notification.object as? String,
                  let section = AppSection(rawValue: rawValue)
            else { return }
            selectionRaw = section.rawValue
        }
        // Mínimo global da janela. A tela mais "gulosa" hoje é Cartões
        // (sidebar interna 240 + detalhe 520 = 760), somado ao rail e respiros
        // do shell, exige ~900. Arredondado pra 1000 dá folga; 640 de altura
        // mostra ~12 linhas de transação confortavelmente.
        .frame(minWidth: 1000, minHeight: 640)
    }

    @ViewBuilder
    private var selectedSectionView: some View {
        switch selection {
        case .dashboard: DashboardView()
        case .transactions: TransactionsView()
        case .creditCards: CreditCardsView()
        case .accounts: AccountsView()
        case .import: ImportHistoryView(store: environment.importFeatureStore)
        case .categories: CategoriesView()
        case .institutions: SupportedInstitutionsView()
        case .designSystem: DesignSystemView()
        case .profile: ProfileView()
        }
    }
}
