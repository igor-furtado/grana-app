import AppKit
import SwiftUI

private enum EmptyStateMetrics {
    static let maxContentWidth: CGFloat = 620
    static let maxTextWidth: CGFloat = 560
    static let iconSize: CGFloat = 62
}

/// Estado vazio padronizado do app com a linguagem warm/teal do design system.
///
/// **Use isto em vez de `ContentUnavailableView` direto.** O wrapper centraliza
/// a linguagem visual e permite trocar o look ou adicionar variantes em um
/// único lugar.
struct EmptyStateView<Icon: View, Actions: View>: View {
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
        VStack(spacing: GranaTheme.Spacing.none) {
            if showsIcon {
                icon
                    .padding(.bottom, GranaTheme.Spacing.lg)
            }

            Text(title)
                .font(GranaTheme.Typography.title2)
                .foregroundStyle(GranaTheme.Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: EmptyStateMetrics.maxTextWidth)

            if let descriptionText {
                Text(descriptionText)
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: EmptyStateMetrics.maxTextWidth)
                    .padding(.top, GranaTheme.Spacing.md)
            }

            if showsActions {
                actions
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, GranaTheme.Spacing.xxl)
            }
        }
        .frame(maxWidth: EmptyStateMetrics.maxContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, GranaTheme.Spacing.xl)
        .padding(.vertical, GranaTheme.Spacing.xxxl)
    }
}

/// Resolução cacheada de símbolos SF. Fora da `EmptyStateView` porque tipos
/// genéricos não suportam `static var` armazenado. Acesso é MainActor — bodies
/// SwiftUI rodam no MainActor.
@MainActor
private enum SymbolResolver {
    private static var cache: [String: String] = [:]

    static func resolve(_ name: String) -> String {
        if let cached = cache[name] {
            return cached
        }
        let resolved = compute(name)
        cache[name] = resolved
        return resolved
    }

    private static func compute(_ name: String) -> String {
        if name.hasSuffix(".circle.fill") {
            return name
        }
        var candidates = ["\(name).circle.fill"]
        if name.hasSuffix(".fill") {
            candidates.append("\(name.dropLast(5)).circle.fill")
        }
        for candidate in candidates where exists(candidate) {
            return candidate
        }
        return name
    }

    private static func exists(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }
}

// MARK: - Conveniência sem actions

extension EmptyStateView where Icon == EmptyView {
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

extension EmptyStateView where Actions == EmptyView {
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

extension EmptyStateView where Icon == EmptyView, Actions == EmptyView {
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

/// Tratamento visual padrão para SF Symbols usados em empty states.
struct EmptyStateSymbolIcon: View {
    private let systemName: String

    init(systemName: String) {
        self.systemName = systemName
    }

    var body: some View {
        Image(systemName: Self.resolveSymbol(systemName))
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: EmptyStateMetrics.iconSize, weight: .bold))
            .foregroundStyle(GranaTheme.Palette.ink)
            .shadow(color: GranaTheme.Shadow.accentColor.opacity(0.64), radius: 18, y: 12)
    }

    /// Procura o variant `.circle.fill` do símbolo. Estratégia em ordem:
    /// 1. Se já termina em `.circle.fill`, é o variant — usa direto.
    /// 2. Tenta `<nome>.circle.fill`.
    /// 3. Se o nome termina em `.fill`, tenta `<base>.circle.fill`.
    /// 4. Sem variant disponível, devolve o nome original.
    /// `NSImage(systemSymbolName:)` valida a existência em tempo de execução —
    /// sem ele, símbolos inexistentes renderizariam vazios silenciosamente.
    private static func resolveSymbol(_ name: String) -> String {
        SymbolResolver.resolve(name)
    }
}
