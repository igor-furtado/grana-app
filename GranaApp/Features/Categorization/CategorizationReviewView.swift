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
            NavigationStack {
                content
                    .navigationTitle("Revisar categorizações")
                    .navigationSubtitle(statusSubtitle)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fechar") { dismiss() }
                        }
                        ToolbarItem(placement: .primaryAction) {
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
            }
            .frame(minWidth: 700, minHeight: 600)
        case let .wizard(onImport, onBack, onClose):
            VStack(spacing: 0) {
                content
                    .navigationSubtitle(statusSubtitle)
                wizardBottomBar(onImport: onImport, onBack: onBack, onClose: onClose)
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
                        LazyVStack(spacing: 0) {
                            summaryRow
                            Divider()
                            ForEach(store.suggestions.indices, id: \.self) { idx in
                                CategorizationRowView(store: store, index: idx)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
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
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .frame(maxHeight: .infinity)
        }
    }

    /// Linha de resumo logo abaixo do header — mesmo tratamento visual da
    /// `TransactionsSelectionRow` do import. Aqui não há checkbox (revisão
    /// é caso a caso, não em lote) — só o texto de progresso.
    private var summaryRow: some View {
        HStack(spacing: 12) {
            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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

    /// Status detalhado da categorização vira o `navigationSubtitle` do sheet
    /// (mesmo lugar que o filename ocupa em `OFXReviewStepView`). Liberta o
    /// espaço dentro do card pro conteúdo principal.
    private var statusSubtitle: String {
        switch store.status {
        case .idle:
            return ""
        case let .classifying(_, _, message):
            return message
        case let .ready(total, fallback):
            return "\(total) transações · \(fallback) pendentes de revisão"
        case let .failed(message):
            return message
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if case .classifying = store.status {
            VStack(spacing: 12) {
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
            Button("Voltar") { onBack() }
            Button {
                Task { await onImport() }
            } label: {
                Text("Importar \(store.suggestions.count) \(store.suggestions.count == 1 ? "transação" : "transações")")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.suggestions.isEmpty || isClassifying)
        }
    }

    private var isClassifying: Bool {
        if case .classifying = store.status { return true }
        return false
    }
}
