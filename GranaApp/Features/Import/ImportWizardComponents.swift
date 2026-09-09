import AppUI
import SwiftUI

struct ImportWizardStep: Hashable {
    let title: String
    let state: State

    enum State {
        case completed
        case current
        case pending
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

    static func presentedSteps(currentStage: Self) -> [ImportWizardStep] {
        allCases.map { stage in
            ImportWizardStep(
                title: stage.title,
                state: stage.stepState(relativeTo: currentStage)
            )
        }
    }

    private func stepState(relativeTo currentStage: Self) -> ImportWizardStep.State {
        if rawValue < currentStage.rawValue {
            return .completed
        }
        if self == currentStage {
            return .current
        }
        return .pending
    }
}

struct ImportWizardInlineSteps: View {
    let steps: [ImportWizardStep]

    var body: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    Rectangle()
                        .fill(connectorColor(before: index))
                        .frame(width: 28, height: 1)
                }

                stepView(step, index: index)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func stepView(_ step: ImportWizardStep, index: Int) -> some View {
        HStack(spacing: AppUI.Theme.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(fillColor(for: step.state))
                    .frame(width: 24, height: 24)
                Circle()
                    .strokeBorder(strokeColor(for: step.state), lineWidth: 1.5)
                    .frame(width: 24, height: 24)

                if step.state == .completed {
                    AppIcon(.completedStep, size: AppUI.Theme.IconSize.micro, weight: .bold)
                        .foregroundStyle(AppUI.Theme.Palette.creamText)
                } else {
                    Text("\(index + 1)")
                        .font(AppUI.Theme.Typography.footnoteEmphasis)
                        .foregroundStyle(numberColor(for: step.state))
                }
            }

            if step.state == .current {
                Text(step.title)
                    .font(AppUI.Theme.Typography.calloutEmphasis)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
            }
        }
    }

    private var accessibilityLabel: String {
        steps.enumerated()
            .map { index, step in "\(index + 1). \(step.title)" }
            .joined(separator: ", ")
    }

    private func fillColor(for state: ImportWizardStep.State) -> Color {
        switch state {
        case .completed, .current:
            AppUI.Theme.Palette.teal
        case .pending:
            .clear
        }
    }

    private func strokeColor(for state: ImportWizardStep.State) -> Color {
        switch state {
        case .completed, .current:
            AppUI.Theme.Palette.teal
        case .pending:
            AppUI.Theme.Palette.line
        }
    }

    private func numberColor(for state: ImportWizardStep.State) -> Color {
        switch state {
        case .current:
            AppUI.Theme.Palette.creamText
        case .completed, .pending:
            AppUI.Theme.Palette.muted
        }
    }

    private func connectorColor(before index: Int) -> Color {
        steps[index - 1].state == .completed ? AppUI.Theme.Palette.teal : AppUI.Theme.Palette.line
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
