import SwiftUI

extension AppUI {
    enum Form {}
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
