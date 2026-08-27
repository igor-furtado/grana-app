import SwiftUI

/// Tela de revisão das classificações sugeridas antes da importação.
///
/// Visual segue o mesmo padrão do `OFXReviewStepView`: `Form { Section }`
/// nativo com **uma única row** contendo `ScrollView { LazyVStack { ... } }`.
/// Assim ganhamos:
/// - Visual de card grouped idêntico à `AccountInfoCard` (Form `.grouped`).
/// - Virtualização real das sugestões via `LazyVStack` (mesmo com 500+ rows).
///
/// Dois modos:
/// - `.modal`: NavigationStack próprio + toolbar com Fechar/Confirmar tudo.
/// - `.wizard(onImport:onBack:)`: bottom bar com Voltar/Importar.
struct CategorizationReviewView: View {
    enum Mode {
        case modal
        case wizard(
            onImport: @MainActor () async -> Void,
            onBack: @MainActor () -> Void,
            onClose: @MainActor () -> Void
        )
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var store: CategorizationStore
    var mode: Mode = .modal

    var body: some View {
        switch mode {
        case .modal:
            VStack(spacing: GranaTheme.Spacing.none) {
                content
                BottomActionBar {
                    Button("Fechar") { dismiss() }
                    Button {
                        Task {
                            await store.confirmAll()
                            dismiss()
                        }
                    } label: {
                        Text("Confirmar tudo")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.suggestions.allSatisfy { $0.isReviewed })
                }
            }
            .toolbar(.hidden, for: .windowToolbar)
            .frame(minWidth: 700, minHeight: 600)
        case let .wizard(onImport, onBack, onClose):
            ImportWizardStageScaffold() {
                VStack(spacing: GranaTheme.Spacing.md) {
                    content
                    wizardBottomBar(onImport: onImport, onBack: onBack, onClose: onClose)
                }
            } 
        }
    }

    // MARK: - Form (núcleo)

    @ViewBuilder
    private var content: some View {
        if store.suggestions.isEmpty {
            emptyState
        } else {
            // Mesma estrutura do `TransactionsListCard` em ImportView:
            // Form { Section { ScrollView { LazyVStack { ... } } } }.
            // Form materializa só UMA row (o ScrollView); a LazyVStack
            // virtualiza as sugestões — handle de 500+ sem travar.
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
                    Text(headerTitle)
                }
            }
            .formStyle(.grouped)
            .contentMargins(.horizontal, GranaTheme.Spacing.none, for: .scrollContent)
            .frame(maxHeight: .infinity)
        }
    }

    /// Linha de resumo logo abaixo do header — mesmo tratamento visual da
    /// `TransactionsSelectionRow` do import. Aqui não há checkbox (revisão
    /// é caso a caso, não em lote) — só o texto de progresso.
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

    private var headerTitle: String {
        "Pendentes de revisão"
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

    // MARK: - Bottom bar (wizard)

    private func wizardBottomBar(
        onImport: @escaping @MainActor () async -> Void,
        onBack: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void
    ) -> some View {
        // Caption omitida — stats de revisão vivem no `summaryRow` da lista.
        BottomActionBar {
            Button("Fechar") { onClose() }
                .buttonStyle(GranaSecondaryButtonStyle())
            Button("Voltar") { onBack() }
                .buttonStyle(GranaSecondaryButtonStyle())
            Button {
                Task { await onImport() }
            } label: {
                Text("Importar \(store.suggestions.count) \(store.suggestions.count == 1 ? "transação" : "transações")")
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(store.suggestions.isEmpty || isClassifying)
        }
    }

    private var isClassifying: Bool {
        if case .classifying = store.status { return true }
        return false
    }

    private var reviewedCount: Int {
        store.suggestions.filter(\.isReviewed).count
    }

    private var fallbackCount: Int {
        if case let .ready(_, fallback) = store.status {
            return fallback
        }
        return store.suggestions.filter { suggestion in
            categoryName(for: suggestion.categoryId).caseInsensitiveCompare("Não Classificado") == .orderedSame
        }.count
    }


    private func categoryName(for id: UUID) -> String {
        store.category(for: id)?.name ?? ""
    }
}
