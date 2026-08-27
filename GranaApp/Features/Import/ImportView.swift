import SwiftUI
import UniformTypeIdentifiers

/// Wizard de importação OFX/CSV apresentado como **sheet modal** sobre a tela
/// de Transações (e a partir da tela de Histórico de Importações). Não vive
/// na navegação principal — sempre é triggerado pelo usuário via botão
/// "Importar extrato" ou pelo drag & drop da tela de histórico.
///
/// **Por que `@State` pra `ImportStore`:** store é local à apresentação, não
/// faz sentido subir pra `AppEnvironment`. Quando o modal é fechado, o store
/// some junto — cada nova abertura começa em `.idle`.
///
/// **Composição:** este arquivo só lida com (a) bootstrap do store, (b)
/// roteamento de `phase` → step view e (c) o `fileImporter` do sistema. Cada
/// step do enum `Phase` vive num arquivo separado em [Steps/], pra essa view
/// não virar um catch-all de 800+ linhas.
struct ImportView: View {
    /// Quando setado, pula o file picker do sistema e carrega esse arquivo
    /// diretamente — usado pelo drag & drop da tela de histórico, onde o
    /// usuário já indicou o arquivo soltando-o na janela.
    let initialFile: URL?

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var store: ImportStore?
    @State private var fileImporterShown = false
    /// Marcada como `true` no callback do `fileImporter` quando o usuário
    /// efetivamente escolhe um arquivo (ou bate num erro real). Permite
    /// distinguir cancelamento do picker (binding flipa pra false sem
    /// callback) de seleção bem-sucedida, e fechar a sheet no primeiro caso.
    @State private var fileWasPicked = false
    /// Guard contra `initialize()` rodar duas vezes — `.task` pode reentrar
    /// se a sheet for re-renderizada antes do `await loadInitialData()`
    /// retornar (raríssimo, mas o efeito colateral seria dois pickers
    /// abrindo em sequência).
    @State private var didInitialize = false

    init(initialFile: URL? = nil) {
        self.initialFile = initialFile
    }

    var body: some View {
        NavigationStack {
            Group {
                if let store {
                    wizard(store: store)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task { initialize() }
                }
            }
            .fileImporter(
                isPresented: $fileImporterShown,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    if let url = urls.first {
                        fileWasPicked = true
                        Task { await store?.loadFile(url: url) }
                    }
                case let .failure(err):
                    fileWasPicked = true
                    store?.reportFileImportFailure(err)
                }
            }
            .onChange(of: fileImporterShown) { _, isShown in
                if isShown {
                    fileWasPicked = false
                    return
                }
                // Picker fechou. Se não houve seleção, é cancelamento — fecha
                // a sheet, já que o botão que abriu também dispara o picker.
                // Delay curto pra dar tempo do callback do fileImporter rodar
                // antes da gente decidir (ordem entre callback e binding flip
                // não é garantida no SwiftUI).
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(80))
                    if !fileWasPicked { dismiss() }
                }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        // Sheet sem cap de altura crescia além da janela em telas pequenas.
        // Limita o tamanho mantendo um ideal confortável.
        .frame(
            minWidth: 880, idealWidth: 980, maxWidth: 1160,
            minHeight: 620, idealHeight: 720, maxHeight: 840
        )
        .background(GranaBackground())
    }

    private func initialize() {
        guard !didInitialize else { return }
        didInitialize = true
        let s = ImportStore(container: environment.container)
        store = s
        Task {
            // Sequenciamento crítico: `loadInitialData` popula `accounts` /
            // `institutions`, que `loadCSV` e o picker de conta no preview OFX
            // precisam ler. Sem o await aqui, `loadCSV` pode rodar contra um
            // `accounts` vazio e falhar com `noCreditCardAccount` mesmo quando
            // o usuário tem conta-cartão cadastrada.
            await s.loadInitialData()
            guard !Task.isCancelled else { return }

            if let initialFile {
                // Drop: usuário já indicou o arquivo. Pula o picker.
                await s.loadFile(url: initialFile)
            } else {
                // Manual: abre o picker do sistema pra escolher arquivo.
                fileImporterShown = true
            }
        }
    }

    private func wizard(store: ImportStore) -> some View {
        VStack(spacing: GranaTheme.Spacing.lg) {
            if let stepperIndex = Self.stepperIndex(for: store.phase) {
                WizardStepper(
                    steps: ["Revisar", "Classificar", "Concluir"],
                    currentIndex: stepperIndex
                )
                .padding(.horizontal, GranaTheme.Spacing.xl)
                .padding(.top, GranaTheme.Spacing.xl)
            }
            phaseContent(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(GranaBackground())
        // `.done` fecha a sheet — toast verde com undo cobre o feedback.
        // `.failed` NÃO fecha: se o usuário já estava no meio da revisão e
        // perdeu o trabalho, ele precisa ver a tela de erro com opção
        // explícita de Recomeçar ou Fechar. O toast vermelho que vem junto
        // mostra a causa.
        .onChange(of: store.phase) { _, newPhase in
            if case .done = newPhase { dismiss() }
        }
    }

    /// Mapeia a `Phase` do wizard pro índice atual do stepper.
    /// `nil` = stepper escondido (idle, loading, failed).
    /// `steps.count` (3) = todos os steps marcados como concluídos.
    private static func stepperIndex(for phase: ImportStore.Phase) -> Int? {
        switch phase {
        case .idle, .loading, .failed:
            return nil
        case .ofxReview, .csvReview:
            return 0
        case .categorizing, .reviewingCategorization:
            return 1
        case .confirming:
            return 2
        case .done:
            return 3
        }
    }

    @ViewBuilder
    private func phaseContent(store: ImportStore) -> some View {
        switch store.phase {
        case .idle:
            ImportWizardStatusView(
                icon: AppIcon.importFile,
                title: "Preparando importação",
                message: "Carregando contas e catálogos antes da revisão do arquivo.",
                showsProgress: true
            )
        case let .loading(progress):
            ImportWizardStatusView(
                icon: AppIcon.importFile,
                title: "Lendo arquivo",
                message: progress,
                showsProgress: true
            )
        case .ofxReview:
            OFXReviewStepView(store: store, dismiss: dismiss)
        case .csvReview:
            CSVReviewStepView(store: store, dismiss: dismiss)
        case .categorizing:
            CategorizingStepView(store: store)
        case .reviewingCategorization:
            // Tela de revisão como step do wizard, com botões "Voltar" e
            // "Importar". `onImport` chama `finalizeImport` que commita
            // atomicamente; `onBack` volta pro preview sem mexer no banco.
            CategorizationReviewView(
                store: store.categorization,
                mode: .wizard(
                    onImport: { await store.finalizeImport() },
                    onBack: { store.backToPreviewFromReview() },
                    onClose: { dismiss() }
                )
            )
        case .confirming:
            ImportWizardStatusView(
                icon: AppIcon.completedSeal,
                title: "Consolidando lotes",
                message: "Aplicando a revisão e finalizando a importação.",
                showsProgress: true
            )
        case .done:
            // Placeholder pro frame entre a transição de fase e o `dismiss()`
            // disparado no `onChange`. Nunca fica visível na prática.
            Color.clear
        case let .failed(message):
            FailedStepView(
                message: message,
                onRetry: {
                    // Cancel reseta phase pra `.idle` e limpa drafts; reabrir
                    // o picker dá ao usuário a chance de escolher outro
                    // arquivo (ou o mesmo, caso a falha tenha sido transiente).
                    store.cancel()
                    fileImporterShown = true
                },
                onClose: { dismiss() }
            )
        }
    }
}

/// Tela final pra erros que param o wizard. Dá ao usuário escolha explícita
/// de recomeçar (volta pro `.idle` e reabre o picker) ou fechar. Substitui
/// auto-dismiss + toast: quando o `.failed` vem depois da revisão, perder o
/// wizard sem mais nada é confuso.
private struct FailedStepView: View {
    let message: String
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        ImportWizardStatusView(
            icon: .warning,
            title: "A importação falhou",
            message: message,
            showsProgress: false
        ) {
            HStack(spacing: GranaTheme.Spacing.sm) {
                Button("Fechar") {
                    onClose()
                }
                .buttonStyle(GranaSecondaryButtonStyle())

                Button("Recomeçar") {
                    onRetry()
                }
                .buttonStyle(GranaPrimaryButtonStyle())
            }
        }
    }
}

private struct ImportWizardStatusView<Actions: View>: View {
    let icon: AppIcon
    let title: String
    let message: String
    let showsProgress: Bool
    let actions: Actions

    init(
        icon: AppIcon,
        title: String,
        message: String,
        showsProgress: Bool,
        @ViewBuilder actions: () -> Actions
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.showsProgress = showsProgress
        self.actions = actions()
    }

    init(
        icon: AppIcon,
        title: String,
        message: String,
        showsProgress: Bool
    ) where Actions == EmptyView {
        self.init(
            icon: icon,
            title: title,
            message: message,
            showsProgress: showsProgress
        ) {
            EmptyView()
        }
    }

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            VStack(spacing: GranaTheme.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 92, height: 92)

                    Circle()
                        .strokeBorder(tint.opacity(0.18), lineWidth: 1)
                        .frame(width: 92, height: 92)

                    Image(systemName: icon.systemImage)
                        .font(.system(size: GranaTheme.IconSize.hero, weight: .regular))
                        .foregroundStyle(tint)
                }

                VStack(spacing: GranaTheme.Spacing.sm) {
                    Text(title)
                        .font(GranaTheme.Typography.title3)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(GranaTheme.Typography.callout)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                if showsProgress {
                    ProgressView()
                        .controlSize(.large)
                        .tint(GranaTheme.Palette.teal)
                }

                actions
                    .controlSize(.large)
            }
            .frame(maxWidth: 560)
            .padding(GranaTheme.Spacing.xxxl)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(GranaTheme.Spacing.xl)
        .background(GranaBackground())
    }

    private var tint: Color {
        switch icon {
        case .warning, .error:
            GranaTheme.Palette.red
        case .completedSeal:
            GranaTheme.Palette.green
        default:
            GranaTheme.Palette.teal
        }
    }
}
