import SwiftUI

public enum Wizard {
    public struct Step: Hashable {
        public let title: String
        public let state: State

        public enum State {
            case completed
            case current
            case pending
        }

        public init(title: String, state: State) {
            self.title = title
            self.state = state
        }
    }

    public struct Shell<Content: View>: View {
        @ViewBuilder private let content: () -> Content

        public init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }

        public var body: some View {
            VStack(spacing: Theme.Spacing.lg) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(GranaBackground())
        }
    }

    public struct Layout<MainContent: View, SidebarActions: View>: View {
        private let steps: [Step]
        private let mainContent: MainContent
        private let sidebarActions: SidebarActions

        public init(
            steps: [Step],
            @ViewBuilder mainContent: () -> MainContent,
            @ViewBuilder sidebarActions: () -> SidebarActions
        ) {
            self.steps = steps
            self.mainContent = mainContent()
            self.sidebarActions = sidebarActions()
        }

        public var body: some View {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
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

private extension Wizard {
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
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.none) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        stepRow(step, index: index)
                    }
                }

                Spacer(minLength: Theme.Spacing.none)

                VStack(spacing: Theme.Spacing.sm) {
                    actions
                        .controlSize(.large)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxHeight: .infinity, alignment: .top)
            .granaSurface(.solid, cornerRadius: Theme.Radius.card)
        }

        @ViewBuilder
        private func stepRow(_ step: Step, index: Int) -> some View {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(fillColor(for: step.state))
                        .frame(width: 24, height: 24)
                    Circle()
                        .strokeBorder(strokeColor(for: step.state), lineWidth: 1.5)
                        .frame(width: 24, height: 24)

                    if step.state == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: Theme.IconSize.micro, weight: .bold))
                            .foregroundStyle(Theme.Palette.creamText)
                    } else {
                        Text("\(index + 1)")
                            .font(Theme.Typography.footnoteEmphasis)
                            .foregroundStyle(numberColor(for: step.state))
                    }
                }

                Text(step.title)
                    .font(step.state == .current ? Theme.Typography.calloutEmphasis : Theme.Typography.callout)
                    .foregroundStyle(labelColor(for: step.state))

                Spacer(minLength: Theme.Spacing.none)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .overlay(alignment: .bottomLeading) {
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(connectorColor(at: index))
                        .frame(width: 1.5, height: 18)
                        .offset(x: 11, y: Theme.Spacing.lg)
                }
            }
        }

        private func fillColor(for state: Step.State) -> Color {
            switch state {
            case .completed, .current:
                Theme.Palette.teal
            case .pending:
                .clear
            }
        }

        private func strokeColor(for state: Step.State) -> Color {
            switch state {
            case .completed, .current:
                Theme.Palette.teal
            case .pending:
                Theme.Palette.line
            }
        }

        private func numberColor(for state: Step.State) -> Color {
            switch state {
            case .current:
                Theme.Palette.creamText
            case .completed, .pending:
                Theme.Palette.muted
            }
        }

        private func labelColor(for state: Step.State) -> Color {
            switch state {
            case .completed, .current:
                Theme.Palette.ink
            case .pending:
                Theme.Palette.muted
            }
        }

        private func connectorColor(at index: Int) -> Color {
            steps[index].state == .completed ? Theme.Palette.teal : Theme.Palette.line
        }
    }
}
