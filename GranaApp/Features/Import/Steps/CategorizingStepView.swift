import ComposableArchitecture
import SwiftUI

struct CategorizingStepView: View {
    @Bindable var store: StoreOf<CategorizationFeature>
    let onCancel: () -> Void

    private enum LoadingStage {
        case preparing
        case finishing
    }

    var body: some View {
        AppUI.Wizard.Shell {
            AppUI.Wizard.Layout(steps: ImportWizardStage.presentedSteps(currentStage: .classification)) {
                loadingCard
            } sidebarActions: {
                Button("Cancelar") { onCancel() }
                    .buttonStyle(GranaSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var loadingCard: some View {
        VStack(spacing: GranaTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(GranaTheme.Palette.teal.opacity(0.10))
                    .frame(width: 112, height: 112)
                Circle()
                    .strokeBorder(GranaTheme.Palette.teal.opacity(0.18), lineWidth: 1)
                    .frame(width: 112, height: 112)

                Image(systemName: AppIcon.completedSeal.systemImage)
                    .font(.system(size: GranaTheme.IconSize.hero, weight: .regular))
                    .foregroundStyle(GranaTheme.Palette.tealDeep)
            }

            progressIndicator

            VStack(spacing: GranaTheme.Spacing.xs) {
                Text(headlineText)
                    .font(GranaTheme.Typography.title3)
                    .foregroundStyle(GranaTheme.Palette.ink)

                statusText
            }
        }
        .padding(.horizontal, GranaTheme.Spacing.xxxl)
        .padding(.vertical, GranaTheme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
    }

    @ViewBuilder
    private var progressIndicator: some View {
        switch store.status {
        case let .classifying(processed, total, _) where total > 0:
            ProgressView(value: Double(processed), total: Double(total))
                .progressViewStyle(.linear)
                .tint(GranaTheme.Palette.teal)
                .frame(maxWidth: 360)
                .animation(.easeOut(duration: 0.25), value: processed)
        default:
            ProgressView()
                .progressViewStyle(.linear)
                .tint(GranaTheme.Palette.teal)
                .frame(maxWidth: 360)
        }
    }

    private var headlineText: String {
        switch store.status {
        case .idle:
            "Preparando classificação"
        case .classifying:
            "Classificando transações"
        case .ready:
            "Revisão pronta"
        case .failed:
            "Falha na classificação"
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch store.status {
        case .idle:
            Text("Carregando categorias e contexto necessário para a próxima etapa.")
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)
                .multilineTextAlignment(.center)
        case let .classifying(processed, total, message):
            VStack(spacing: GranaTheme.Spacing.xs) {
                Text("\(processed) de \(total) processadas")
                    .font(GranaTheme.Typography.calloutEmphasis)
                    .foregroundStyle(GranaTheme.Palette.ink)

                TimelineView(.periodic(from: .now, by: 1.8)) { context in
                    Text(rotatingMessage(for: loadingStage(processed: processed, total: total, message: message), date: context.date))
                        .font(GranaTheme.Typography.callout)
                        .foregroundStyle(GranaTheme.Palette.muted)
                }
            }
        case .ready:
            EmptyView()
        case let .failed(message):
            Text(message)
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)
                .multilineTextAlignment(.center)
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
                "Separando descrições e padrões locais…",
                "Organizando transações para revisão…",
                "Aplicando heurísticas antes do commit…",
            ]
        case .finishing:
            messages = [
                "Montando a tela de revisão…",
                "Consolidando sugestões finais…",
                "Preparando a etapa de conferência…",
            ]
        }

        let slot = Int(date.timeIntervalSinceReferenceDate / 1.8)
        return messages[abs(slot) % messages.count]
    }
}
