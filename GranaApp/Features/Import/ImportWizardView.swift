import AppUI
import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct ImportWizardView: View {
    @Bindable var store: StoreOf<ImportWizardFeature>
    let onClose: () -> Void
    @State private var fileImporterShown = false
    @State private var fileWasPicked = false
    @State private var didTriggerPicker = false

    var body: some View {
        wizard
            .fileImporter(
                isPresented: $fileImporterShown,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    if let url = urls.first {
                        fileWasPicked = true
                        store.send(.fileSelected(url))
                    }
                case let .failure(error):
                    fileWasPicked = true
                    store.send(.fileLoaded(.failure(error)))
                }
            }
            .onChange(of: fileImporterShown) { _, isShown in
                if isShown {
                    fileWasPicked = false
                    return
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(80))
                    if !fileWasPicked {
                        onClose()
                    }
                }
            }
            .onChange(of: store.phase) { _, phase in
                if case .done = phase {
                    onClose()
                }
            }
            .task {
                await store.send(.task).finish()
            }
            .onAppear {
                guard !didTriggerPicker,
                      store.initialFile == nil
                else { return }
                didTriggerPicker = true
                fileImporterShown = true
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(GranaBackground())
    }

    private var wizard: some View {
        phaseContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(GranaBackground())
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch store.phase {
        case .idle:
            ImportWizardStatusView(
                icon: AppUI.Icon.importFile,
                title: "Preparando importação",
                message: "Carregando contas e catálogos antes da revisão do arquivo.",
                showsProgress: true
            )
        case let .loading(progress):
            ImportWizardStatusView(
                icon: AppUI.Icon.importFile,
                title: "Lendo arquivo",
                message: progress,
                showsProgress: true
            )
        case .ofxReview:
            if let ofxStore = store.scope(state: \.ofx, action: \.ofx) {
                OFXReviewStepView(
                    store: ofxStore,
                    onClose: onClose,
                    onConfirm: { store.send(.confirmOFXImport) }
                )
            }
        case .csvReview:
            if let csvStore = store.scope(state: \.csv, action: \.csv) {
                CSVReviewStepView(
                    store: csvStore,
                    onClose: onClose,
                    onConfirm: { store.send(.confirmCSVImport) }
                )
            }
        case .categorizing:
            if let reviewStore = store.scope(state: \.review, action: \.review) {
                ImportCategorizationView(
                    store: reviewStore.scope(state: \.categorization, action: \.categorization),
                    onCancel: { store.send(.backToPreview) }
                )
            }
        case .reviewingCategorization:
            if let reviewStore = store.scope(state: \.review, action: \.review) {
                CategorizationReviewView(
                    store: reviewStore.scope(state: \.categorization, action: \.categorization),
                    mode: .wizard(
                        onImport: { store.send(.finalizeImport) },
                        onBack: { store.send(.backToPreview) },
                        onClose: onClose
                    )
                )
            }
        case .confirming:
            ImportWizardStatusView(
                icon: AppUI.Icon.completedSeal,
                title: "Consolidando lotes",
                message: "Aplicando a revisão e finalizando a importação.",
                showsProgress: true
            )
        case .done:
            Color.clear
        case let .failed(message):
            FailedStepView(
                message: message,
                onRetry: {
                    store.send(.cancel)
                    fileImporterShown = true
                },
                onClose: onClose
            )
        }
    }
}

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
            HStack(spacing: AppUI.Theme.Spacing.sm) {
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
    let icon: AppUI.Icon
    let title: String
    let message: String
    let showsProgress: Bool
    let actions: Actions

    init(
        icon: AppUI.Icon,
        title: String,
        message: String,
        showsProgress: Bool,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.showsProgress = showsProgress
        self.actions = actions()
    }

    var body: some View {
        AppUI.Wizard.Shell {
            IllustratedStatusView(
                title,
                icon: icon,
                description: message
            ) {
                if showsProgress {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 320)
                        .tint(AppUI.Theme.Palette.teal)
                }

                actions
            }
        }
    }
}
