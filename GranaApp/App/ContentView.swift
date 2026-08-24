import SwiftUI

/// Seções principais do app, exibidas no rail lateral autenticado.
///
/// A ordem visual do rail é determinada por `ContentView.primaryRailItems` e
/// `ContentView.bottomRailItems`, não pela ordem do `enum`.
enum AppSection: String, Hashable, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case creditCards
    case accounts
    case `import`
    case categories
    case institutions
    case designSystem
    case profile

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .transactions: "Transações"
        case .creditCards: "Cartões de crédito"
        case .accounts: "Contas"
        case .import: "Importar dados"
        case .categories: "Categorias"
        case .institutions: "Instituições"
        case .designSystem: "Design System"
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
        case .categories: .sidebarCategories
        case .institutions: .sidebarInstitutions
        case .designSystem: .sidebarDesignSystem
        case .profile: .sidebarProfile
        }
    }
}

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment

    /// Restaurado entre sessões via `@SceneStorage` — abrir o app cai na
    /// última seção visitada (UX padrão macOS). `rawValue: String` é o que o
    /// SceneStorage persiste; reconstruímos o `AppSection` no getter abaixo.
    /// Default `.dashboard` cobre o primeiro lançamento + casos de raw value
    /// inválido (ex: enum mudou entre versões).
    @SceneStorage("ContentView.selection") private var selectionRaw: String = AppSection.dashboard.rawValue

    private static let primaryRailItems: [AppSection] = [
        .dashboard,
        .transactions,
        .creditCards,
        .accounts,
        .import,
    ]

    private static let bottomRailItems: [AppSection] = [
        .designSystem,
        .categories,
        .institutions,
        .profile,
    ]

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
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var authenticatedContent: some View {
        ZStack {
            GranaBackground()
            HStack(spacing: 12) {
                rail
                    .padding(GranaTheme.Layout.railInsets)

                NavigationStack {
                    selectedSectionView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.trailing, 18)
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
        case .import: ImportHistoryView()
        case .categories: CategoriesView()
        case .institutions: SupportedInstitutionsView()
        case .designSystem: DesignSystemView()
        case .profile: ProfileView()
        }
    }

    private var rail: some View {
        VStack(spacing: 8) {
            ForEach(Self.primaryRailItems) { section in
                railButton(for: section)
            }

            Spacer(minLength: 14)

            ForEach(Self.bottomRailItems) { section in
                railButton(for: section)
            }
        }
        .padding(10)
        .frame(width: 70)
        .frame(maxHeight: .infinity)
        .granaSurface(.glass, cornerRadius: GranaTheme.Radius.rail)
    }

    private func railButton(for section: AppSection) -> some View {
        let isSelected = selection == section
        return Button {
            selectionRaw = section.rawValue
        } label: {
            Image(systemName: section.icon.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? GranaTheme.Palette.creamText : GranaTheme.Palette.muted)
                .frame(width: 48, height: 48)
                .background {
                    if isSelected {
                        GranaTheme.brandGradient()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: GranaTheme.Shadow.accentColor, radius: 17, y: 8)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(section.title)
        .accessibilityLabel(section.title)
    }
}
