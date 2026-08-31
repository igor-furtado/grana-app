import SwiftUI

extension AppUI {
    enum Wizard {}
}

extension AppUI.Wizard {
    struct Step: Hashable {
        let title: String
        let state: State

        enum State {
            case completed
            case current
            case pending
        }
    }

    struct Shell<Content: View>: View {
        @ViewBuilder private let content: () -> Content

        init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }

        var body: some View {
            VStack(spacing: GranaTheme.Spacing.lg) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(GranaTheme.Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(GranaBackground())
        }
    }

    struct Layout<MainContent: View, SidebarActions: View>: View {
        private let steps: [Step]
        private let mainContent: MainContent
        private let sidebarActions: SidebarActions

        init(
            steps: [Step],
            @ViewBuilder mainContent: () -> MainContent,
            @ViewBuilder sidebarActions: () -> SidebarActions
        ) {
            self.steps = steps
            self.mainContent = mainContent()
            self.sidebarActions = sidebarActions()
        }

        var body: some View {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Sidebar(steps: steps) {
                    sidebarActions
                }
                .frame(width: 210)
            }
        }
    }
}

private extension AppUI.Wizard {
    struct Sidebar<Actions: View>: View {
        let steps: [Step]
        let actions: Actions

        init(
            steps: [Step],
            @ViewBuilder actions: () -> Actions
        ) {
            self.steps = steps
            self.actions = actions()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.none) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        stepRow(step, index: index)
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
        private func stepRow(_ step: Step, index: Int) -> some View {
            HStack(alignment: .center, spacing: GranaTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(fillColor(for: step.state))
                        .frame(width: 24, height: 24)
                    Circle()
                        .strokeBorder(strokeColor(for: step.state), lineWidth: 1.5)
                        .frame(width: 24, height: 24)

                    if step.state == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: GranaTheme.IconSize.micro, weight: .bold))
                            .foregroundStyle(GranaTheme.Palette.creamText)
                    } else {
                        Text("\(index + 1)")
                            .font(GranaTheme.Typography.footnoteEmphasis)
                            .foregroundStyle(numberColor(for: step.state))
                    }
                }

                Text(step.title)
                    .font(step.state == .current ? GranaTheme.Typography.calloutEmphasis : GranaTheme.Typography.callout)
                    .foregroundStyle(labelColor(for: step.state))

                Spacer(minLength: GranaTheme.Spacing.none)
            }
            .padding(.vertical, GranaTheme.Spacing.sm)
            .overlay(alignment: .bottomLeading) {
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(connectorColor(at: index))
                        .frame(width: 1.5, height: 18)
                        .offset(x: 11, y: GranaTheme.Spacing.lg)
                }
            }
        }

        private func fillColor(for state: Step.State) -> Color {
            switch state {
            case .completed, .current:
                GranaTheme.Palette.teal
            case .pending:
                .clear
            }
        }

        private func strokeColor(for state: Step.State) -> Color {
            switch state {
            case .completed, .current:
                GranaTheme.Palette.teal
            case .pending:
                GranaTheme.Palette.line
            }
        }

        private func numberColor(for state: Step.State) -> Color {
            switch state {
            case .current:
                GranaTheme.Palette.creamText
            case .completed, .pending:
                GranaTheme.Palette.muted
            }
        }

        private func labelColor(for state: Step.State) -> Color {
            switch state {
            case .completed, .current:
                GranaTheme.Palette.ink
            case .pending:
                GranaTheme.Palette.muted
            }
        }

        private func connectorColor(at index: Int) -> Color {
            steps[index].state == .completed ? GranaTheme.Palette.teal : GranaTheme.Palette.line
        }
    }
}
