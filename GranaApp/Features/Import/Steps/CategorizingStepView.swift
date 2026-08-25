import SwiftUI

/// Step intermediário: classificação local antes do commit.
///
struct CategorizingStepView: View {
    @Bindable var store: ImportStore

    private enum LoadingStage {
        case preparing
        case finishing
    }

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.lg) {
            loadingCard
            Button("Cancelar") { store.backToPreviewFromReview() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, GranaTheme.Spacing.xxxl)
    }

    private var loadingCard: some View {
        VStack(spacing: GranaTheme.Spacing.md) {
            progressIndicator
            statusText
        }
        // Padding interno generoso pra que o halo interno do glow tenha
        // espaço pra "invadir" sem cobrir o conteúdo.
        .padding(.horizontal, GranaTheme.Spacing.xxl)
        .padding(.vertical, GranaTheme.Spacing.xl)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var progressIndicator: some View {
        switch store.categorization.status {
        case let .classifying(processed, total, _) where total > 0:
            ProgressView(value: Double(processed), total: Double(total))
                .progressViewStyle(.linear)
                .animation(.easeOut(duration: 0.25), value: processed)
        default:
            ProgressView()
                .progressViewStyle(.linear)
        }
    }

    /// Só renderiza os sub-estados que o usuário consegue ler antes de o
    /// `awaitCategorizationCompletion` trocar a `phase` — `.ready` e `.failed`
    /// transicionam direto pra `.reviewingCategorization`, então nunca aparecem
    /// aqui.
    @ViewBuilder
    private var statusText: some View {
        switch store.categorization.status {
        case .idle:
            Text("Preparando classificação…").foregroundStyle(.secondary)
        case let .classifying(processed, total, message):
            TimelineView(.periodic(from: .now, by: 1.8)) { context in
                Text(rotatingMessage(
                    for: loadingStage(
                        processed: processed,
                        total: total,
                        message: message
                    ),
                    date: context.date
                ))
                .foregroundStyle(.secondary)
            }
        case .ready, .failed:
            EmptyView()
        }
    }

    private func loadingStage(processed: Int, total: Int, message: String) -> LoadingStage {
        if message.contains("Finalizando") || (total > 0 && processed >= total) {
            return .finishing
        }
        return .preparing
    }

    private func rotatingMessage(for stage: LoadingStage, date: Date) -> String {
        let messages: [String]
        switch stage {
        case .preparing:
            messages = [
                "Preparando classificação…",
                "Organizando transações…",
                "Separando descrições…",
            ]
        case .finishing:
            messages = [
                "Finalizando…",
                "Montando revisão…",
                "Aplicando padrões locais…",
            ]
        }

        let slot = Int(date.timeIntervalSinceReferenceDate / 1.8)
        return messages[abs(slot) % messages.count]
    }
}
