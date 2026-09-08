import AppUI
import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct ImportWizardView: View {
    @Bindable var store: StoreOf<ImportWizardFeature>
    let onClose: @MainActor @Sendable () -> Void
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
        case .triage:
            if let triageStore = store.scope(state: \.triage, action: \.triage) {
                ImportTriageView(
                    store: triageStore,
                    onClose: onClose
                )
            }
        case .categorizing:
            if let categorizationStore = store.scope(state: \.categorization, action: \.categorization) {
                ImportCategorizationView(
                    store: categorizationStore,
                    onCancel: { store.send(.backToPreview) }
                )
            }
        case .reviewingCategorization:
            if let reviewStore = store.scope(state: \.review, action: \.review) {
                ImportReviewView(
                    store: reviewStore,
                    mode: .wizard(
                        onBack: { store.send(.backToPreview) }
                    )
                )
            }
        case .confirming:
            if let commitStore = store.scope(state: \.commit, action: \.commit) {
                ImportCommitView(store: commitStore)
            }
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
