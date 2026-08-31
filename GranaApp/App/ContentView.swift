import ComposableArchitecture
import SwiftUI
import AppUI

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
                .foregroundStyle(AppUI.Theme.Palette.ink)
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
            .padding(AppUI.Theme.Spacing.xl)
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
            VStack(spacing: AppUI.Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(AppUI.Theme.Palette.teal.opacity(0.18))
                        .frame(width: 96, height: 96)
                    Image(systemName: AppUI.Icon.importFile.systemImage)
                        .font(.system(size: AppUI.Theme.IconSize.hero, weight: .regular))
                        .foregroundStyle(AppUI.Theme.Palette.tealDeep)
                }
                Text("Solte o extrato para revisar")
                    .font(AppUI.Theme.Typography.title3)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
                Text("OFX ou CSV em qualquer tela")
                    .font(AppUI.Theme.Typography.callout)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }
            .padding(AppUI.Theme.Spacing.xxxl)
            .background {
                RoundedRectangle(cornerRadius: AppUI.Theme.Radius.hero, style: .continuous)
                    .fill(AppUI.Theme.Palette.paper.opacity(0.92))
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppUI.Theme.Radius.hero, style: .continuous)
                    .strokeBorder(
                        AppUI.Theme.Palette.teal.opacity(0.40),
                        style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                    )
            }
            .shadow(color: AppUI.Theme.Shadow.cardColor, radius: 24, y: 10)
            .padding(AppUI.Theme.Spacing.xxxl)
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
    @State private var categoriesFeatureStore: StoreOf<CategoriesFeature>
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
        _categoriesFeatureStore = State(initialValue: Store(initialState: CategoriesFeature.State()) {
            CategoriesFeature()
        } withDependencies: {
            $0.categoriesClient = .live(container: container)
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
        let isWorkspaceModalPresented = environment.importFeatureStore.wizard != nil

        ZStack {
            GranaBackground()
            HStack(spacing: AppUI.Theme.Spacing.none) {
                AppNavigationRail(selection: selection) { section in
                    activate(section)
                }
                .padding(AppUI.Theme.Layout.railInsets)

                shellContent
                    .padding(AppUI.Theme.Layout.pageInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .allowsHitTesting(!isWorkspaceModalPresented)
            .accessibilityHidden(isWorkspaceModalPresented)
        }
        .dropDestination(for: URL.self, action: handleImportDrop, isTargeted: setImportDropTargeted)
        .overlay {
            if isImportDropTargeted, environment.importFeatureStore.wizard == nil {
                GlobalImportDropOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if let wizardStore = environment.importFeatureStore.scope(state: \.wizard, action: \.wizard) {
                ImportOverlayContainer(
                    onClose: { environment.importFeatureStore.send(.wizard(.cancel)) }
                ) {
                    ImportView(store: wizardStore) {
                        environment.importFeatureStore.send(.wizard(.cancel))
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: isImportDropTargeted)
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
            TransactionsView(store: transactionsFeatureStore)
        case .creditCards:
            CreditCardsView(store: environment.creditCardsFeatureStore)
        case .accounts:
            AccountsView(store: accountsFeatureStore)
        case .import:
            ImportHistoryView(store: environment.importFeatureStore)
        case .categories:
            CategoriesView(store: categoriesFeatureStore)
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

private struct ImportOverlayContainer<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    private let minimumWidth: CGFloat = 1080
    private let minimumHeight: CGFloat = 620
    private let widthRatio: CGFloat = 0.82
    private let heightRatio: CGFloat = 0.84

    var body: some View {
        GeometryReader { proxy in
            let width = overlayWidth(for: proxy.size.width)
            let height = overlayHeight(for: proxy.size.height)

            AppUI.Modal.Workspace(width: width, height: height, onDismiss: onClose) {
                content()
            }
        }
    }

    private func overlayWidth(for containerWidth: CGFloat) -> CGFloat {
        let horizontalInset = AppUI.Theme.Spacing.xl * 2
        let availableWidth = max(minimumWidth, containerWidth - horizontalInset)
        let proportionalWidth = max(minimumWidth, containerWidth * widthRatio)
        return min(availableWidth, proportionalWidth)
    }

    private func overlayHeight(for containerHeight: CGFloat) -> CGFloat {
        let verticalInset = AppUI.Theme.Spacing.xl * 2
        let availableHeight = max(minimumHeight, containerHeight - verticalInset)
        let proportionalHeight = max(minimumHeight, containerHeight * heightRatio)
        return min(availableHeight, proportionalHeight)
    }
}
