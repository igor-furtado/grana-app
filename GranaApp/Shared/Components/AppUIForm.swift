import SwiftUI

public enum Form {
    public struct Shell<Content: View>: View {
        @ViewBuilder private let content: () -> Content

        public init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                content()
            }
            .padding(.vertical, Theme.Spacing.lg)
            .granaSurface(.subtle, cornerRadius: Theme.Radius.card)
            .padding(Theme.Spacing.sm)
        }
    }

    public struct Header<Trailing: View>: View {
        let title: String
        let subtitle: String?
        @ViewBuilder private let trailing: () -> Trailing

        public init(
            title: String,
            subtitle: String? = nil,
            @ViewBuilder trailing: @escaping () -> Trailing
        ) {
            self.title = title
            self.subtitle = subtitle
            self.trailing = trailing
        }

        public init(
            title: String,
            subtitle: String? = nil
        ) where Trailing == EmptyView {
            self.title = title
            self.subtitle = subtitle
            self.trailing = { EmptyView() }
        }

        public var body: some View {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.title3)
                        .foregroundStyle(Theme.Palette.ink)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.Palette.muted)
                    }
                }

                Spacer(minLength: Theme.Spacing.none)

                trailing()
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    public struct SectionHeader: View {
        public let title: String

        public init(title: String) {
            self.title = title
        }

        public var body: some View {
            Text(title)
                .font(Theme.Typography.subheadlineEmphasis)
                .foregroundStyle(Theme.Palette.ink)
                .textCase(nil)
        }
    }

    public struct SectionFooter: View {
        public let text: String

        public init(text: String) {
            self.text = text
        }

        public var body: some View {
            Text(text)
                .font(Theme.Typography.footnote)
                .foregroundStyle(Theme.Palette.muted)
                .textCase(nil)
        }
    }

    public struct Actions<Trailing: View>: View {
        let caption: String?
        @ViewBuilder private let trailing: () -> Trailing

        public init(
            caption: String? = nil,
            @ViewBuilder trailing: @escaping () -> Trailing
        ) {
            self.caption = caption
            self.trailing = trailing
        }

        public var body: some View {
            HStack(spacing: Theme.Spacing.sm) {
                if let caption {
                    Text(caption)
                        .font(Theme.Typography.caption1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trailing()
                    .controlSize(.large)
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    public struct ErrorMessage: View {
        public let message: String

        public init(message: String) {
            self.message = message
        }

        public var body: some View {
            Label {
                Text(message)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(.danger)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.danger)
            }
        }
    }
}

public enum Modal {
    public struct Workspace<Content: View>: View {
        @ViewBuilder private let content: () -> Content
        @FocusState private var isModalFocused: Bool
        private let width: CGFloat
        private let height: CGFloat
        private let onDismiss: (() -> Void)?

        public init(
            width: CGFloat,
            height: CGFloat,
            onDismiss: (() -> Void)? = nil,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.width = width
            self.height = height
            self.onDismiss = onDismiss
            self.content = content
        }

        public var body: some View {
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(0.62)

                content()
                    .frame(width: width, height: height)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                            .fill(Theme.Palette.paper.opacity(0.94))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                            .strokeBorder(Theme.Palette.line.opacity(0.55), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
                    .shadow(color: Theme.Shadow.glassColor, radius: 30, y: 16)
                    .padding(Theme.Spacing.xl)
                    .focusable()
                    .focused($isModalFocused)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                isModalFocused = true
            }
            .onExitCommand {
                onDismiss?()
            }
        }
    }
}
