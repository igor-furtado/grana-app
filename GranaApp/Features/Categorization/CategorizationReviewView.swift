import ComposableArchitecture
import SwiftUI

struct CategorizationReviewView: View {
    enum Mode {
        case modal
        case wizard(
            onImport: @MainActor () -> Void,
            onBack: @MainActor () -> Void,
            onClose: @MainActor () -> Void
        )
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var store: StoreOf<CategorizationFeature>
    var mode: Mode = .modal

    var body: some View {
        switch mode {
        case .modal:
            VStack(spacing: GranaTheme.Spacing.none) {
                content
                BottomActionBar {
                    Button("Fechar") { dismiss() }
                    Button {
                        store.send(.confirmAll)
                        dismiss()
                    } label: {
                        Text("Confirmar tudo")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.suggestions.allSatisfy(\.isReviewed))
                }
            }
            .toolbar(.hidden, for: .windowToolbar)
            .frame(minWidth: 700, minHeight: 600)
        case let .wizard(onImport, onBack, onClose):
            ImportWizardStageScaffold {
                VStack(spacing: GranaTheme.Spacing.md) {
                    content
                    wizardBottomBar(onImport: onImport, onBack: onBack, onClose: onClose)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.suggestions.isEmpty {
            emptyState
        } else {
            Form {
                Section {
                    ScrollView {
                        LazyVStack(spacing: GranaTheme.Spacing.none) {
                            summaryRow
                            Divider()
                            ForEach(store.suggestions.indices, id: \.self) { idx in
                                CategorizationRowView(store: store, index: idx)
                                    .padding(.horizontal, GranaTheme.Spacing.md)
                                    .padding(.vertical, GranaTheme.Spacing.xs)
                                Divider()
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Pendentes de revisão")
                }
            }
            .formStyle(.grouped)
            .contentMargins(.horizontal, GranaTheme.Spacing.none, for: .scrollContent)
            .frame(maxHeight: .infinity)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            Text(summaryText)
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .padding(.vertical, GranaTheme.Spacing.xs)
        .background(Color.primary.opacity(0.03))
    }

    private var summaryText: String {
        let total = store.suggestions.count
        let reviewed = store.suggestions.filter(\.isReviewed).count
        return "\(reviewed) de \(total) revisadas"
    }

    @ViewBuilder
    private var emptyState: some View {
        if case .classifying = store.status {
            VStack(spacing: GranaTheme.Spacing.sm) {
                ProgressView()
                Text("Categorizando…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyStateView(
                "Tudo categorizado",
                icon: .success,
                description: "Sem sugestões pendentes pra revisar."
            )
        }
    }

    private func wizardBottomBar(
        onImport: @escaping @MainActor () -> Void,
        onBack: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void
    ) -> some View {
        BottomActionBar {
            Button("Fechar") { onClose() }
                .buttonStyle(GranaSecondaryButtonStyle())
            Button("Voltar") { onBack() }
                .buttonStyle(GranaSecondaryButtonStyle())
            Button {
                onImport()
            } label: {
                Text("Importar \(store.suggestions.count) \(store.suggestions.count == 1 ? "transação" : "transações")")
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(store.suggestions.isEmpty || isClassifying)
        }
    }

    private var isClassifying: Bool {
        if case .classifying = store.status {
            return true
        }
        return false
    }
}
