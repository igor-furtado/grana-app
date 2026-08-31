import SwiftUI

extension AppUI {
    enum Form {}
    enum Modal {}
}

extension AppUI.Form {
    struct Shell<Content: View>: View {
        @ViewBuilder private let content: () -> Content

        init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }

        var body: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                content()
            }
            .padding(.vertical, GranaTheme.Spacing.lg)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
            .padding(GranaTheme.Spacing.sm)
        }
    }

    struct Header<Trailing: View>: View {
        let title: String
        let subtitle: String?
        @ViewBuilder private let trailing: () -> Trailing

        init(
            title: String,
            subtitle: String? = nil,
            @ViewBuilder trailing: @escaping () -> Trailing
        ) {
            self.title = title
            self.subtitle = subtitle
            self.trailing = trailing
        }

        init(
            title: String,
            subtitle: String? = nil
        ) where Trailing == EmptyView {
            self.title = title
            self.subtitle = subtitle
            self.trailing = { EmptyView() }
        }

        var body: some View {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                    Text(title)
                        .font(GranaTheme.Typography.title3)
                        .foregroundStyle(GranaTheme.Palette.ink)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(GranaTheme.Typography.subheadline)
                            .foregroundStyle(GranaTheme.Palette.muted)
                    }
                }

                Spacer(minLength: GranaTheme.Spacing.none)

                trailing()
            }
            .padding(.horizontal, GranaTheme.Spacing.lg)
        }
    }

    struct SectionHeader: View {
        let title: String

        var body: some View {
            Text(title)
                .font(GranaTheme.Typography.subheadlineEmphasis)
                .foregroundStyle(GranaTheme.Palette.ink)
                .textCase(nil)
        }
    }

    struct SectionFooter: View {
        let text: String

        var body: some View {
            Text(text)
                .font(GranaTheme.Typography.footnote)
                .foregroundStyle(GranaTheme.Palette.muted)
                .textCase(nil)
        }
    }

    struct Actions<Trailing: View>: View {
        let caption: String?
        @ViewBuilder private let trailing: () -> Trailing

        init(
            caption: String? = nil,
            @ViewBuilder trailing: @escaping () -> Trailing
        ) {
            self.caption = caption
            self.trailing = trailing
        }

        var body: some View {
            BottomActionBar(caption: caption) {
                trailing()
            }
        }
    }

    struct ErrorMessage: View {
        let message: String

        var body: some View {
            Label {
                Text(message)
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(.danger)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.danger)
            }
        }
    }
}

extension AppUI.Modal {
    struct Workspace<Content: View>: View {
        @ViewBuilder private let content: () -> Content
        @FocusState private var isModalFocused: Bool
        private let width: CGFloat
        private let height: CGFloat
        private let onDismiss: (() -> Void)?

        init(
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

        var body: some View {
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(0.62)

                content()
                    .frame(width: width, height: height)
                    .background {
                        RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                            .fill(GranaTheme.Palette.paper.opacity(0.94))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                            .strokeBorder(GranaTheme.Palette.line.opacity(0.55), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous))
                    .shadow(color: GranaTheme.Shadow.glassColor, radius: 30, y: 16)
                    .padding(GranaTheme.Spacing.xl)
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
