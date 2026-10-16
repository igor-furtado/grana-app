import AppKit
import SwiftUI
import AppUI

private enum IllustratedStatusMetrics {
    static let maxContentWidth: CGFloat = 620
    static let maxTextWidth: CGFloat = 560
    static let iconContainerSize: CGFloat = 92
}

/// Bloco ilustrado padronizado do app para estados compactos, overlays e feedbacks.
///
/// **Use isto em vez de `ContentUnavailableView` direto.** O wrapper centraliza
/// a linguagem visual e permite trocar o look ou adicionar variantes em um
/// único lugar.
struct IllustratedStatusView<Icon: View, Actions: View>: View {
    private let title: String
    private let descriptionText: String?
    private let icon: Icon
    private let showsIcon: Bool
    private let actions: Actions
    private let showsActions: Bool

    init(
        _ title: String,
        description: String? = nil,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.descriptionText = description
        self.icon = icon()
        self.showsIcon = true
        self.actions = actions()
        self.showsActions = true
    }

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.none) {
            if showsIcon {
                icon
                    .padding(.bottom, AppUI.Theme.Spacing.lg)
            }

            Text(title)
                .font(AppUI.Theme.Typography.title2)
                .foregroundStyle(AppUI.Theme.Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: IllustratedStatusMetrics.maxTextWidth)

            if let descriptionText {
                Text(descriptionText)
                    .font(AppUI.Theme.Typography.callout)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: IllustratedStatusMetrics.maxTextWidth)
                    .padding(.top, AppUI.Theme.Spacing.md)
            }

            if showsActions {
                actions
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, AppUI.Theme.Spacing.xxl)
            }
        }
        .frame(maxWidth: IllustratedStatusMetrics.maxContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppUI.Theme.Spacing.xl)
        .padding(.vertical, AppUI.Theme.Spacing.xxxl)
    }
}

// MARK: - Conveniência sem actions

extension IllustratedStatusView where Icon == EmptyView {
    init(
        _ title: String,
        description: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.descriptionText = description
        self.icon = EmptyView()
        self.showsIcon = false
        self.actions = actions()
        self.showsActions = true
    }
}

extension IllustratedStatusView where Actions == EmptyView {
    init(
        _ title: String,
        description: String? = nil,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        self.descriptionText = description
        self.icon = icon()
        self.showsIcon = true
        self.actions = EmptyView()
        self.showsActions = false
    }
}

extension IllustratedStatusView where Icon == EmptyView, Actions == EmptyView {
    init(
        _ title: String,
        description: String? = nil
    ) {
        self.title = title
        self.descriptionText = description
        self.icon = EmptyView()
        self.showsIcon = false
        self.actions = EmptyView()
        self.showsActions = false
    }
}

/// Estado vazio padronizado do app com a linguagem warm/teal do design system.
struct EmptyStateView<Icon: View, Actions: View>: View {
    private let content: IllustratedStatusView<Icon, Actions>

    init(
        _ title: String,
        description: String? = nil,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder actions: () -> Actions
    ) {
        self.content = IllustratedStatusView(
            title,
            description: description,
            icon: icon,
            actions: actions
        )
    }

    var body: some View {
        content
    }
}

// MARK: - Conveniência sem actions

extension EmptyStateView where Icon == EmptyView {
    init(
        _ title: String,
        description: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.content = IllustratedStatusView(
            title,
            description: description,
            actions: actions
        )
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(
        _ title: String,
        description: String? = nil,
        @ViewBuilder icon: () -> Icon
    ) {
        self.content = IllustratedStatusView(
            title,
            description: description,
            icon: icon
        )
    }
}

extension EmptyStateView where Icon == EmptyView, Actions == EmptyView {
    init(
        _ title: String,
        description: String? = nil
    ) {
        self.content = IllustratedStatusView(
            title,
            description: description
        )
    }
}

/// Tratamento visual padrão para SF Symbols usados em empty states.
struct EmptyStateSymbolIcon: View {
    private let systemName: String

    init(systemName: String) {
        self.systemName = systemName
    }

    var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: AppUI.Theme.IconSize.hero, weight: .regular))
            .foregroundStyle(AppUI.Theme.Palette.tealDeep)
            .frame(
                width: IllustratedStatusMetrics.iconContainerSize,
                height: IllustratedStatusMetrics.iconContainerSize
            )
            .background(
                AppUI.Theme.Palette.teal.opacity(0.10),
                in: Circle()
            )
    }
}
