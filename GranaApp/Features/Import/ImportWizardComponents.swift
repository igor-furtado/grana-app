import SwiftUI

struct ImportWizardStageScaffold<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.lg) {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, GranaTheme.Spacing.xl)
        .padding(.bottom, GranaTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GranaBackground())
    }
}

enum ImportWizardStage: Int, CaseIterable {
    case triage
    case classification
    case review

    var title: String {
        switch self {
        case .triage:
            "Triagem"
        case .classification:
            "Classificação"
        case .review:
            "Revisão"
        }
    }
}

struct ImportWizardSplitLayout<MainContent: View, SidebarActions: View>: View {
    let currentStage: ImportWizardStage
    let mainContent: MainContent
    let sidebarActions: SidebarActions

    init(
        currentStage: ImportWizardStage,
        @ViewBuilder mainContent: () -> MainContent,
        @ViewBuilder sidebarActions: () -> SidebarActions
    ) {
        self.currentStage = currentStage
        self.mainContent = mainContent()
        self.sidebarActions = sidebarActions()
    }

    var body: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            ImportWizardSidebar(currentStage: currentStage) {
                sidebarActions
            }
            .frame(width: 280)
        }
    }
}

private struct ImportWizardSidebar<Actions: View>: View {
    let currentStage: ImportWizardStage
    let actions: Actions

    init(
        currentStage: ImportWizardStage,
        @ViewBuilder actions: () -> Actions
    ) {
        self.currentStage = currentStage
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.none) {
                ForEach(ImportWizardStage.allCases, id: \.rawValue) { stage in
                    stepRow(for: stage)
                }
            }

            Spacer(minLength: GranaTheme.Spacing.none)

            VStack(spacing: GranaTheme.Spacing.sm) {
                actions
                    .controlSize(.large)
            }
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxHeight: .infinity, alignment: .top)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
    }

    @ViewBuilder
    private func stepRow(for stage: ImportWizardStage) -> some View {
        let visualState = visualState(for: stage)

        HStack(alignment: .center, spacing: GranaTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(fillColor(for: visualState))
                    .frame(width: 24, height: 24)
                Circle()
                    .strokeBorder(strokeColor(for: visualState), lineWidth: 1.5)
                    .frame(width: 24, height: 24)

                if visualState == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: GranaTheme.IconSize.micro, weight: .bold))
                        .foregroundStyle(GranaTheme.Palette.creamText)
                } else {
                    Text("\(stage.rawValue + 1)")
                        .font(GranaTheme.Typography.footnoteEmphasis)
                        .foregroundStyle(numberColor(for: visualState))
                }
            }

            Text(stage.title)
                .font(visualState == .current ? GranaTheme.Typography.calloutEmphasis : GranaTheme.Typography.callout)
                .foregroundStyle(labelColor(for: visualState))

            Spacer(minLength: GranaTheme.Spacing.none)
        }
        .padding(.vertical, GranaTheme.Spacing.sm)
        .overlay(alignment: .bottomLeading) {
            if stage != .review {
                Rectangle()
                    .fill(connectorColor(for: stage))
                    .frame(width: 1.5, height: 18)
                    .offset(x: 11, y: GranaTheme.Spacing.lg)
            }
        }
    }

    private enum VisualState {
        case completed
        case current
        case pending
    }

    private func visualState(for stage: ImportWizardStage) -> VisualState {
        if stage.rawValue < currentStage.rawValue {
            return .completed
        }
        if stage == currentStage {
            return .current
        }
        return .pending
    }

    private func fillColor(for state: VisualState) -> Color {
        switch state {
        case .completed, .current:
            GranaTheme.Palette.teal
        case .pending:
            .clear
        }
    }

    private func strokeColor(for state: VisualState) -> Color {
        switch state {
        case .completed, .current:
            GranaTheme.Palette.teal
        case .pending:
            GranaTheme.Palette.line
        }
    }

    private func numberColor(for state: VisualState) -> Color {
        switch state {
        case .current:
            GranaTheme.Palette.creamText
        case .completed, .pending:
            GranaTheme.Palette.muted
        }
    }

    private func labelColor(for state: VisualState) -> Color {
        switch state {
        case .completed, .current:
            GranaTheme.Palette.ink
        case .pending:
            GranaTheme.Palette.muted
        }
    }

    private func connectorColor(for stage: ImportWizardStage) -> Color {
        stage.rawValue < currentStage.rawValue ? GranaTheme.Palette.teal : GranaTheme.Palette.line
    }
}

struct ImportWizardSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let trailing: AnyView?
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        trailing: AnyView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.none) {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text(title)
                        .font(GranaTheme.Typography.headline)
                        .foregroundStyle(GranaTheme.Palette.ink)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(GranaTheme.Typography.caption1)
                            .foregroundStyle(GranaTheme.Palette.muted)
                    }
                }

                Spacer(minLength: GranaTheme.Spacing.none)
                trailing
            }
            .padding(GranaTheme.Spacing.md)

            content()
        }
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
    }
}

struct ImportWizardMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: GranaTheme.Spacing.sm) {
            Text(label)
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(GranaTheme.Palette.muted)
            Spacer(minLength: GranaTheme.Spacing.none)
            Text(value)
                .font(GranaTheme.Typography.calloutEmphasis)
                .foregroundStyle(GranaTheme.Palette.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct ImportWizardInfoRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
            Text(label)
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(GranaTheme.Palette.muted)
            content()
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ImportWizardBadge: Identifiable {
    enum Tint {
        case teal
        case gold
        case green
        case warning
        case neutral

        var background: Color {
            switch self {
            case .teal:
                GranaTheme.Palette.teal.opacity(0.14)
            case .gold:
                GranaTheme.Palette.gold.opacity(0.22)
            case .green:
                GranaTheme.Palette.green.opacity(0.15)
            case .warning:
                Color.warning.opacity(0.16)
            case .neutral:
                GranaTheme.Palette.soft
            }
        }

        var foreground: Color {
            switch self {
            case .teal:
                GranaTheme.Palette.tealDeep
            case .gold:
                GranaTheme.Palette.ink
            case .green:
                GranaTheme.Palette.green
            case .warning:
                .secondary
            case .neutral:
                GranaTheme.Palette.ink
            }
        }
    }

    let id = UUID()
    let label: String
    let tint: Tint
}

struct ImportWizardBadgeView: View {
    let badge: ImportWizardBadge

    var body: some View {
        Text(badge.label)
            .font(GranaTheme.Typography.caption1Emphasis)
            .foregroundStyle(badge.tint.foreground)
            .padding(.horizontal, GranaTheme.Spacing.sm)
            .padding(.vertical, GranaTheme.Spacing.xs)
            .background(badge.tint.background, in: Capsule())
    }
}
