import SwiftUI

struct ImportWizardStageScaffold<Content: View, Sidebar: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: AppIcon
    let badges: [ImportWizardBadge]
    @ViewBuilder var content: () -> Content
    @ViewBuilder var sidebar: () -> Sidebar

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.lg) {
            hero

            HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                sidebar()
                    .frame(width: 280, alignment: .top)
            }
        }
        .padding(.horizontal, GranaTheme.Spacing.xl)
        .padding(.bottom, GranaTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GranaBackground())
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(GranaTheme.Palette.teal.opacity(0.14))
                    .frame(width: 72, height: 72)

                Image(systemName: icon.systemImage)
                    .font(.system(size: GranaTheme.IconSize.large, weight: .regular))
                    .foregroundStyle(GranaTheme.Palette.tealDeep)
            }

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                Text(eyebrow.uppercased())
                    .font(GranaTheme.Typography.caption1Emphasis)
                    .foregroundStyle(GranaTheme.Palette.tealDeep)

                Text(title)
                    .font(GranaTheme.Typography.title2)
                    .foregroundStyle(GranaTheme.Palette.ink)

                Text(subtitle)
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if !badges.isEmpty {
                    HStack(spacing: GranaTheme.Spacing.xs) {
                        ForEach(badges) { badge in
                            ImportWizardBadgeView(badge: badge)
                        }
                    }
                }
            }

            Spacer(minLength: GranaTheme.Spacing.none)
        }
        .padding(GranaTheme.Spacing.xl)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
    }
}

struct ImportWizardSidebarCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
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

            content()
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
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

            Divider()

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
