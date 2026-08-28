import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isImportDropTargeted = false

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
                    loginContent
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
        .frame(minWidth: 1280, minHeight: 820)
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
        .frame(minWidth: 1280, minHeight: 820)
    }

    private var loginContent: some View {
        ZStack {
            GranaBackground()

            LoginView(authService: environment.authService)
        }
        .frame(minWidth: 1280, minHeight: 820)
    }

    private var authenticatedContent: some View {
        AuthenticatedShellView(
            selectionRaw: $selectionRaw,
            container: environment.container
        )
        .id(ObjectIdentifier(environment.container))
        .environment(environment)
        .frame(minWidth: 1280, minHeight: 820)
    }
}

private struct GlobalImportDropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(0.84)
            VStack(spacing: GranaTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(GranaTheme.Palette.teal.opacity(0.18))
                        .frame(width: 96, height: 96)
                    Image(systemName: AppIcon.importFile.systemImage)
                        .font(.system(size: GranaTheme.IconSize.hero, weight: .regular))
                        .foregroundStyle(GranaTheme.Palette.tealDeep)
                }
                Text("Solte o extrato para revisar")
                    .font(GranaTheme.Typography.title3)
                    .foregroundStyle(GranaTheme.Palette.ink)
                Text("OFX ou CSV em qualquer tela")
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
            .padding(GranaTheme.Spacing.xxxl)
            .background {
                RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                    .fill(GranaTheme.Palette.paper.opacity(0.92))
            }
            .overlay {
                RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                    .strokeBorder(
                        GranaTheme.Palette.teal.opacity(0.40),
                        style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                    )
            }
            .shadow(color: GranaTheme.Shadow.cardColor, radius: 24, y: 10)
            .padding(GranaTheme.Spacing.xxxl)
        }
    }
}

private struct AppShellBranchView<Root: View>: View {
    @Bindable var branch: AppShellBranch
    let isActive: Bool
    @ViewBuilder let root: () -> Root

    var body: some View {
        NavigationStack(path: $branch.path) {
            root()
        }
        .opacity(isActive ? 1 : 0)
        .allowsHitTesting(isActive)
        .accessibilityHidden(!isActive)
        .zIndex(isActive ? 1 : 0)
    }
}

private struct AuthenticatedShellView: View {
    @Environment(AppEnvironment.self) private var environment
    @Binding var selectionRaw: String
    @State private var isImportDropTargeted = false
    @State private var shellStore: AppShellStore
    @State private var accountsFeatureStore: StoreOf<AccountsFeature>
    @State private var transactionsFeatureStore: StoreOf<TransactionsFeature>
    @State private var supportedInstitutionsFeatureStore: StoreOf<SupportedInstitutionsFeature>

    init(selectionRaw: Binding<String>, container: AppContainer) {
        _selectionRaw = selectionRaw
        _shellStore = State(initialValue: AppShellStore())
        _accountsFeatureStore = State(initialValue: Store(initialState: AccountsFeature.State()) {
            AccountsFeature()
        } withDependencies: {
            $0.accountsClient = .live(container: container)
        })
        _transactionsFeatureStore = State(initialValue: Store(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionsClient = .live(container: container)
        })
        _supportedInstitutionsFeatureStore = State(
            initialValue: Store(initialState: SupportedInstitutionsFeature.State()) {
                SupportedInstitutionsFeature()
            } withDependencies: {
                $0.supportedInstitutionsClient = .live(container: container)
            }
        )
    }

    private var selection: AppSection {
        AppSection(rawValue: selectionRaw) ?? .dashboard
    }

    var body: some View {
        ZStack {
            GranaBackground()
            HStack(spacing: GranaTheme.Spacing.none) {
                AppNavigationRail(selection: selection) { section in
                    activate(section)
                }
                .padding(GranaTheme.Layout.railInsets)

                shellContent
                    .padding(GranaTheme.Layout.pageInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay {
            if selection == .transactions {
                TransactionFormDrawerOverlay(store: transactionsFeatureStore)
                    .zIndex(1)
            }
        }
        .dropDestination(for: URL.self, action: handleImportDrop, isTargeted: setImportDropTargeted)
        .overlay {
            if isImportDropTargeted, environment.importFeatureStore.wizard == nil {
                GlobalImportDropOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isImportDropTargeted)
        .sheet(
            isPresented: Binding(
                get: { environment.importFeatureStore.wizard != nil },
                set: { isPresented in
                    if !isPresented {
                        environment.importFeatureStore.send(.wizard(.cancel))
                    }
                }
            )
        ) {
            if let wizardStore = environment.importFeatureStore.scope(state: \.wizard, action: \.wizard) {
                ImportView(store: wizardStore)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appSectionNavigationRequested)) { notification in
            guard let rawValue = notification.object as? String,
                  let section = AppSection(rawValue: rawValue)
            else { return }
            activate(section)
        }
        .onAppear { activate(selection) }
    }

    private var shellContent: some View {
        ZStack {
            ForEach(AppSection.allCases) { section in
                if shellStore.isMounted(section) {
                    AppShellBranchView(
                        branch: shellStore.branch(for: section),
                        isActive: section == selection
                    ) {
                        sectionRootView(for: section)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionRootView(for section: AppSection) -> some View {
        switch section {
        case .dashboard:
            DashboardView()
        case .transactions:
            TransactionsView(store: transactionsFeatureStore, showsDrawerOverlay: false)
        case .creditCards:
            CreditCardsView(store: environment.creditCardsFeatureStore)
        case .accounts:
            AccountsView(store: accountsFeatureStore)
        case .import:
            ImportHistoryView(store: environment.importFeatureStore)
        case .categories:
            CategoriesView()
        case .institutions:
            SupportedInstitutionsView(store: supportedInstitutionsFeatureStore)
        case .designSystem:
            DesignSystemView()
        case .profile:
            ProfileView()
        }
    }

    private func handleImportDrop(_ urls: [URL], at _: CGPoint) -> Bool {
        let decision = ImportDropPolicy.evaluate(
            urls: urls,
            supportedExtensions: ImportWizardFeature.State.supportedExtensions,
            isImportInProgress: environment.importFeatureStore.wizard != nil
        )
        environment.importFeatureStore.send(.globalFileDrop(urls))
        return decision.acceptsDrop
    }

    private func setImportDropTargeted(_ targeted: Bool) {
        isImportDropTargeted = targeted
    }

    private func activate(_ section: AppSection) {
        shellStore.activate(section)
        selectionRaw = section.rawValue
    }
}
