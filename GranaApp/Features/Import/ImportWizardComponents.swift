import SwiftUI

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

    static func presentedSteps(currentStage: Self) -> [AppUI.Wizard.Step] {
        allCases.map { stage in
            AppUI.Wizard.Step(
                title: stage.title,
                state: stage.stepState(relativeTo: currentStage)
            )
        }
    }

    private func stepState(relativeTo currentStage: Self) -> AppUI.Wizard.Step.State {
        if rawValue < currentStage.rawValue {
            return .completed
        }
        if self == currentStage {
            return .current
        }
        return .pending
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
    let id = UUID()
    let label: String
    let tint: Tint

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
}

struct ImportWizardTableStatusBadge: View {
    let status: TransactionRow.Status

    var body: some View {
        Text(status.label)
            .font(GranaTheme.Typography.caption1)
            .padding(.horizontal, GranaTheme.Spacing.xs)
            .padding(.vertical, GranaTheme.Spacing.xxs)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status.tint {
        case .warning: .warning.opacity(0.18)
        case .success: .success.opacity(0.15)
        case .info: .accentColor.opacity(0.15)
        case .neutral: .secondary.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch status.tint {
        case .warning: .secondary
        case .success: .success
        case .info: .accentColor
        case .neutral: .secondary
        }
    }
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
