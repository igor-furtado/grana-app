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
        .frame(minWidth: 940, minHeight: 620)
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
        .frame(minWidth: 940, minHeight: 620)
    }

    private var loginContent: some View {
        ZStack {
            GranaBackground()

            LoginView(authService: environment.authService)
        }
        .frame(minWidth: 940, minHeight: 620)
    }

    private var authenticatedContent: some View {
        AuthenticatedShellView(
            selectionRaw: $selectionRaw,
            store: environment.appFeatureStore
        )
        .id(ObjectIdentifier(environment.container))
        .environment(environment)
        .frame(minWidth: 940, minHeight: 620)
    }
}

private struct GlobalImportDropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(AppUI.Theme.Palette.overlayScrim)
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
    @Binding var selectionRaw: String
    @Bindable var store: StoreOf<AppFeature>
    @State private var isImportDropTargeted = false
    @State private var sheetHostSize: CGSize = .zero
    @State private var shellStore: AppShellStore

    init(selectionRaw: Binding<String>, store: StoreOf<AppFeature>) {
        _selectionRaw = selectionRaw
        self.store = store
        _shellStore = State(initialValue: AppShellStore())
    }

    private var selection: AppSection {
        AppSection(rawValue: selectionRaw) ?? .dashboard
    }

    var body: some View {
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
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { sheetHostSize = proxy.size }
                    .onChange(of: proxy.size) { _, newSize in
                        sheetHostSize = newSize
                    }
            }
        }
        .dropDestination(for: URL.self, action: handleImportDrop, isTargeted: setImportDropTargeted)
        .overlay {
            if isImportDropTargeted, store.importFeature.wizard == nil {
                GlobalImportDropOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .allowsHitTesting(false)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { store.importFeature.wizard != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.importFeature(.wizard(.cancel)))
                    }
                }
            )
        ) {
            if let wizardStore = store.scope(state: \.importFeature.wizard, action: \.importFeature.wizard) {
                ImportSheetContainer(hostSize: sheetHostSize) {
                    ImportView(store: wizardStore) {
                        store.send(.importFeature(.wizard(.cancel)))
                    }
                }
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
            TransactionsView(store: store.scope(state: \.transactions, action: \.transactions))
        case .creditCards:
            CreditCardsView(store: store.scope(state: \.creditCards, action: \.creditCards))
        case .accounts:
            AccountsView(store: store.scope(state: \.accounts, action: \.accounts))
        case .import:
            ImportHistoryView(store: store.scope(state: \.importFeature, action: \.importFeature))
        case .categories:
            CategoriesView(store: store.scope(state: \.categories, action: \.categories))
        case .institutions:
            SupportedInstitutionsView(store: store.scope(state: \.supportedInstitutions, action: \.supportedInstitutions))
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
            isImportInProgress: store.importFeature.wizard != nil
        )
        store.send(.importFeature(.globalFileDrop(urls)))
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

private struct ImportSheetContainer<Content: View>: View {
    let hostSize: CGSize
    @ViewBuilder let content: () -> Content

    private var size: CGSize {
        AppUI.Modal.SheetSize.large(in: hostSize)
    }

    var body: some View {
        content()
            .frame(width: size.width, height: size.height)
            .presentationSizing(.fitted)
    }
}
