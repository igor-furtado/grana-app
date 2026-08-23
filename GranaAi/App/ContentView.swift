import SwiftUI

/// Seções principais do app, exibidas na sidebar do `NavigationSplitView`.
///
/// A ordem visual da sidebar é determinada por `AppSection.sidebarItems`,
/// não pela ordem do `enum`.
enum AppSection: String, Hashable, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case creditCards
    case accounts
    case `import`
    case categorization
    case categories
    case institutions
    case profile

    var id: String {
        rawValue
    }

    /// Ordem é **parte do contrato de UI** da sidebar.
    static let sidebarItems: [AppSection] = [
        .dashboard,
        .transactions,
        .creditCards,
        .accounts,
        .import,
        .categorization,
        .categories,
        .institutions,
        .profile,
    ]

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .transactions: "Transações"
        case .creditCards: "Cartões de crédito"
        case .accounts: "Contas"
        case .import: "Importar dados"
        case .categorization: "Categorização"
        case .categories: "Categorias"
        case .institutions: "Instituições"
        case .profile: "Perfil"
        }
    }

    /// Ícone da seção. Delega pro `AppIcon` (catálogo central de chrome de UI)
    /// pra manter strings de SF Symbol num único lugar e evitar typos.
    var icon: AppIcon {
        switch self {
        case .dashboard: .sidebarDashboard
        case .transactions: .sidebarTransactions
        case .creditCards: .sidebarCreditCards
        case .accounts: .sidebarAccounts
        case .import: .sidebarImport
        case .categorization: .sidebarCategorization
        case .categories: .sidebarCategories
        case .institutions: .sidebarInstitutions
        case .profile: .sidebarProfile
        }
    }
}

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment

    /// Override de tema válido só pra sessão atual (não persistido). Toda
    /// abertura do app começa em `nil` (segue o sistema); o botão de tema
    /// na toolbar da sidebar flipa pra `.light`/`.dark` e o estado se perde
    /// ao fechar.
    @State private var themeOverride: ColorScheme?

    /// Lido pra decidir a direção do toggle quando ainda não há override.
    /// Reflete o tema efetivo da janela — sistema quando `themeOverride`
    /// é `nil`, ou o próprio override depois do primeiro clique.
    @Environment(\.colorScheme) private var currentScheme

    /// Restaurado entre sessões via `@SceneStorage` — abrir o app cai na
    /// última seção visitada (UX padrão macOS). `rawValue: String` é o que o
    /// SceneStorage persiste; reconstruímos o `AppSection` no getter abaixo.
    /// Default `.dashboard` cobre o primeiro lançamento + casos de raw value
    /// inválido (ex: enum mudou entre versões).
    @SceneStorage("ContentView.selection") private var selectionRaw: String = AppSection.dashboard.rawValue

    private var selection: AppSection {
        AppSection(rawValue: selectionRaw) ?? .dashboard
    }

    /// Binding pro `List(selection:)`. Optional porque o List aceita "nada
    /// selecionado" — tratamos `nil` como no-op pra preservar a última
    /// seleção válida (evita janela em branco se o sistema desselecionar).
    private var selectionBinding: Binding<AppSection?> {
        Binding(
            get: { AppSection(rawValue: selectionRaw) },
            set: { newValue in
                if let newValue { selectionRaw = newValue.rawValue }
            }
        )
    }

    var body: some View {
        Group {
            if environment.availabilityState == .unavailable {
                unavailableContent
            } else {
                switch environment.authService.state {
                case .restoring:
                    ProgressView("Restaurando sessão…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .unavailable:
                    unavailableContent
                case .unauthenticated:
                    LoginView(authService: environment.authService)
                case .authenticated:
                    authenticatedContent
                }
            }
        }
        .noticeOverlay()
    }

    private var unavailableContent: some View {
        EmptyStateView(
            "Grana AI indisponível",
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
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var authenticatedContent: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            Group {
                switch selection {
                case .dashboard: DashboardView()
                case .transactions: TransactionsView()
                case .creditCards: CreditCardsView()
                case .accounts: AccountsView()
                case .import: ImportHistoryView()
                case .categorization: CategorizationSettingsView()
                case .categories: CategoriesView()
                case .institutions: SupportedInstitutionsView()
                case .profile: ProfileView()
                }
            }
        }
        .navigationTitle("Grana AI")
        .preferredColorScheme(themeOverride)
        .onReceive(NotificationCenter.default.publisher(for: .appSectionNavigationRequested)) { notification in
            guard let rawValue = notification.object as? String,
                  let section = AppSection(rawValue: rawValue)
            else { return }
            selectionRaw = section.rawValue
        }
        // Mínimo global da janela. A tela mais "gulosa" hoje é Cartões
        // (sidebar interna 240 + detalhe 520 = 760), somado à sidebar do
        // app (200), exige ~960. Arredondado pra 1000 dá folga; 640 de
        // altura mostra ~12 linhas de transação confortavelmente.
        .frame(minWidth: 1000, minHeight: 640)
    }

    private func toggleTheme() {
        themeOverride = (currentScheme == .dark) ? .light : .dark
    }

    /// Sidebar padrão do macOS: `List(selection:)` com `Label` nativo.
    /// Seleção, hover, navegação por teclado (setas ↑↓), background
    /// translúcido, suporte a Increase Contrast — tudo grátis do sistema.
    /// Highlight de seleção usa `AccentColor`.
    private var sidebar: some View {
        List(selection: selectionBinding) {
            ForEach(AppSection.sidebarItems) { section in
                Label(section.title, systemImage: section.icon.systemImage)
                    .tag(section)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: toggleTheme) {
                    Label(
                        currentScheme == .dark ? "Tema claro" : "Tema escuro",
                        systemImage: currentScheme == .dark
                            ? AppIcon.themeLight.systemImage
                            : AppIcon.themeDark.systemImage
                    )
                }
                .help(currentScheme == .dark ? "Mudar para tema claro" : "Mudar para tema escuro")
            }
        }
    }

}
