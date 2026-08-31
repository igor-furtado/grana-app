import SwiftUI
import AppUI

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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.none) {
            HStack(alignment: .top, spacing: AppUI.Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                    Text(title)
                        .font(AppUI.Theme.Typography.headline)
                        .foregroundStyle(AppUI.Theme.Palette.ink)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AppUI.Theme.Typography.caption1)
                            .foregroundStyle(AppUI.Theme.Palette.muted)
                    }
                }

                Spacer(minLength: AppUI.Theme.Spacing.none)
                trailing
            }
            .padding(AppUI.Theme.Spacing.md)

            content()
        }
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
    }
}

struct ImportWizardTableStatusBadge: View {
    let status: TransactionRow.Status

    var body: some View {
        Text(status.label)
            .font(AppUI.Theme.Typography.caption1)
            .padding(.horizontal, AppUI.Theme.Spacing.xs)
            .padding(.vertical, AppUI.Theme.Spacing.xxs)
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