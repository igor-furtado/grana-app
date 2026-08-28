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
        case let .wizard(onImport, onBack, _):
            ImportWizardStageScaffold {
                ImportWizardSplitLayout(currentStage: .review) {
                    content
                } sidebarActions: {
                    Button("Voltar") { onBack() }
                        .buttonStyle(GranaSecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    Button("Importar") { onImport() }
                        .buttonStyle(GranaPrimaryButtonStyle())
                        .disabled(store.suggestions.isEmpty || isClassifying)
                        .frame(maxWidth: .infinity)
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
                ForEach(CategorizationReviewOrdering.sections(from: store.suggestions)) { section in
                    Section(section.title) {
                        ForEach(section.indices, id: \.self) { idx in
                            CategorizationRowView(store: store, index: idx)
                                .padding(.horizontal, GranaTheme.Spacing.md)
                                .padding(.vertical, GranaTheme.Spacing.xs)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .contentMargins(.horizontal, GranaTheme.Spacing.none, for: .scrollContent)
            .frame(maxHeight: .infinity)
        }
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

    private var isClassifying: Bool {
        if case .classifying = store.status {
            return true
        }
        return false
    }
}

enum CategorizationReviewOrdering {
    struct Section: Identifiable, Equatable {
        let title: String
        let indices: [Int]

        var id: String { title }
    }

    static func sections(from suggestions: [CategorizationSuggestion]) -> [Section] {
        let indexed: [(index: Int, suggestion: CategorizationSuggestion)] = suggestions.enumerated().map {
            (index: $0.offset, suggestion: $0.element)
        }
        let ordered = indexed.sorted { lhs, rhs in
            if needsAttention(lhs.suggestion) != needsAttention(rhs.suggestion) {
                return needsAttention(lhs.suggestion) && !needsAttention(rhs.suggestion)
            }
            if lhs.suggestion.transactionOccurredAt == rhs.suggestion.transactionOccurredAt {
                return lhs.index < rhs.index
            }
            return lhs.suggestion.transactionOccurredAt < rhs.suggestion.transactionOccurredAt
        }

        let attention = ordered.filter { needsAttention($0.suggestion) }.map(\.index)
        let remaining = ordered.filter { !needsAttention($0.suggestion) }.map(\.index)

        return [
            Section(title: "Não Classificado", indices: attention),
            Section(title: "Demais", indices: remaining),
        ]
        .filter { !$0.indices.isEmpty }
    }

    private static func needsAttention(_ suggestion: CategorizationSuggestion) -> Bool {
        suggestion.source == .fallback || suggestion.originalCategorySlug == "nao-classificado"
    }
}
