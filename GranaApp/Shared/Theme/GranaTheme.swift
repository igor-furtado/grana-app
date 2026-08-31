import AppKit
import SwiftUI

public enum Theme {
    public enum Palette {
        public static let background = Color(red: 0.957, green: 0.941, blue: 0.910)
        public static let backgroundStart = Color(red: 0.973, green: 0.953, blue: 0.910)
        public static let backgroundEnd = Color(red: 0.929, green: 0.957, blue: 0.937)
        public static let ink = Color(red: 0.090, green: 0.137, blue: 0.122)
        public static let paper = Color(red: 1.000, green: 0.988, blue: 0.961)
        public static let paperSolid = Color(red: 1.000, green: 0.980, blue: 0.941)
        public static let teal = Color(red: 0.067, green: 0.478, blue: 0.408)
        public static let tealDeep = Color(red: 0.047, green: 0.373, blue: 0.325)
        public static let green = Color(red: 0.078, green: 0.486, blue: 0.337)
        public static let red = Color(red: 0.788, green: 0.255, blue: 0.227)
        public static let amber = Color(red: 0.847, green: 0.569, blue: 0.169)
        public static let gold = Color(red: 0.929, green: 0.722, blue: 0.373)
        public static let creamText = Color(red: 1.000, green: 0.976, blue: 0.929)

        public static var muted: Color {
            ink.opacity(0.62)
        }

        public static var soft: Color {
            ink.opacity(0.07)
        }

        public static var line: Color {
            ink.opacity(0.13)
        }
    }

    public enum Radius {
        public static let control: CGFloat = 15
        public static let pill: CGFloat = 48
        public static let card: CGFloat = 22
        public static let hero: CGFloat = 32
        public static let rail: CGFloat = 27
    }

    public enum Shadow {
        public static let glassColor = Color(red: 0.161, green: 0.129, blue: 0.086).opacity(0.14)
        public static let cardColor = Palette.ink.opacity(0.07)
        public static let rowColor = Palette.ink.opacity(0.04)
        public static let accentColor = Palette.teal.opacity(0.22)
    }

    public enum Layout {
        public static let pageInsets = EdgeInsets(
            top: Theme.Spacing.none,
            leading: Theme.Spacing.none,
            bottom: Theme.Spacing.lg,
            trailing: Theme.Spacing.lg
        )
        public static let railInsets = EdgeInsets(
            top: Theme.Spacing.none,
            leading: Theme.Spacing.lg,
            bottom: Theme.Spacing.lg,
            trailing: Theme.Spacing.lg
        )
    }

    public enum Typography {
        public struct Token: Identifiable {
            public let name: String
            public let family: Family
            public let size: CGFloat
            public let weight: Weight
            public let usage: String

            public var id: String {
                name
            }

            public var category: String {
                family.category
            }

            public var font: Font {
                Font.system(size: size, weight: weight.fontWeight, design: family.design)
            }

            public var value: String {
                "\(family.displayName) \(Int(size)) \(weight.displayName)"
            }
        }

        public enum Family {
            case text
            case money
            case code

            public var category: String {
                switch self {
                case .text:
                    "Texto"
                case .money:
                    "Dinheiro"
                case .code:
                    "Código"
                }
            }

            public var design: Font.Design {
                switch self {
                case .text:
                    .default
                case .money, .code:
                    .monospaced
                }
            }

            public var displayName: String {
                switch self {
                case .text:
                    "SF Pro"
                case .money, .code:
                    "SF Mono"
                }
            }
        }

        public enum Weight {
            case regular
            case medium
            case semibold
            case bold
            case black

            public var fontWeight: Font.Weight {
                switch self {
                case .regular:
                    .regular
                case .medium:
                    .medium
                case .semibold:
                    .semibold
                case .bold:
                    .bold
                case .black:
                    .black
                }
            }

            public var nsFontWeight: NSFont.Weight {
                switch self {
                case .regular:
                    .regular
                case .medium:
                    .medium
                case .semibold:
                    .semibold
                case .bold:
                    .bold
                case .black:
                    .black
                }
            }

            public var displayName: String {
                switch self {
                case .regular:
                    "regular"
                case .medium:
                    "medium"
                case .semibold:
                    "semibold"
                case .bold:
                    "bold"
                case .black:
                    "black"
                }
            }
        }

        private static let title1Token = Token(
            name: "title1",
            family: .text,
            size: 48,
            weight: .black,
            usage: "Título hero"
        )
        private static let title2Token = Token(
            name: "title2",
            family: .text,
            size: 28,
            weight: .bold,
            usage: "Título amplo"
        )
        private static let title3Token = Token(
            name: "title3",
            family: .text,
            size: 22,
            weight: .semibold,
            usage: "Título compacto"
        )
        private static let headlineToken = Token(
            name: "headline",
            family: .text,
            size: 17,
            weight: .bold,
            usage: "Destaque de seção"
        )
        private static let bodyToken = Token(
            name: "body",
            family: .text,
            size: 15,
            weight: .regular,
            usage: "Leitura contínua"
        )
        private static let bodyEmphasisToken = Token(
            name: "bodyEmphasis",
            family: .text,
            size: 15,
            weight: .semibold,
            usage: "Corpo enfatizado"
        )
        private static let calloutToken = Token(
            name: "callout",
            family: .text,
            size: 14,
            weight: .regular,
            usage: "Apoio ao corpo"
        )
        private static let calloutEmphasisToken = Token(
            name: "calloutEmphasis",
            family: .text,
            size: 14,
            weight: .semibold,
            usage: "Callout enfatizado"
        )
        private static let subheadlineToken = Token(
            name: "subheadline",
            family: .text,
            size: 13,
            weight: .regular,
            usage: "Linhas densas"
        )
        private static let subheadlineEmphasisToken = Token(
            name: "subheadlineEmphasis",
            family: .text,
            size: 13,
            weight: .semibold,
            usage: "Linha densa enfatizada"
        )
        private static let footnoteToken = Token(
            name: "footnote",
            family: .text,
            size: 12,
            weight: .regular,
            usage: "Dados auxiliares"
        )
        private static let footnoteEmphasisToken = Token(
            name: "footnoteEmphasis",
            family: .text,
            size: 12,
            weight: .semibold,
            usage: "Dado auxiliar enfatizado"
        )
        private static let caption1Token = Token(
            name: "caption1",
            family: .text,
            size: 11,
            weight: .medium,
            usage: "Legendas e status"
        )
        private static let caption1EmphasisToken = Token(
            name: "caption1Emphasis",
            family: .text,
            size: 11,
            weight: .bold,
            usage: "Legenda enfatizada"
        )
        private static let caption2Token = Token(
            name: "caption2",
            family: .text,
            size: 10,
            weight: .medium,
            usage: "Microtexto"
        )
        private static let caption2EmphasisToken = Token(
            name: "caption2Emphasis",
            family: .text,
            size: 10,
            weight: .bold,
            usage: "Microtexto enfatizado"
        )
        private static let moneyTitle1Token = Token(
            name: "moneyTitle1",
            family: .money,
            size: 48,
            weight: .bold,
            usage: "Valor financeiro principal"
        )
        private static let moneyTitle2Token = Token(
            name: "moneyTitle2",
            family: .money,
            size: 28,
            weight: .bold,
            usage: "Valor financeiro destacado"
        )
        private static let moneyTitle3Token = Token(
            name: "moneyTitle3",
            family: .money,
            size: 22,
            weight: .bold,
            usage: "Valor financeiro compacto"
        )
        private static let moneyHeadlineToken = Token(
            name: "moneyHeadline",
            family: .money,
            size: 17,
            weight: .semibold,
            usage: "Valor financeiro em seção"
        )
        private static let moneyBodyToken = Token(
            name: "moneyBody",
            family: .money,
            size: 15,
            weight: .semibold,
            usage: "Valor financeiro no corpo"
        )
        private static let moneyCalloutToken = Token(
            name: "moneyCallout",
            family: .money,
            size: 14,
            weight: .semibold,
            usage: "Valor financeiro de apoio"
        )
        private static let moneySubheadlineToken = Token(
            name: "moneySubheadline",
            family: .money,
            size: 13,
            weight: .semibold,
            usage: "Valor financeiro em linha"
        )
        private static let moneyFootnoteToken = Token(
            name: "moneyFootnote",
            family: .money,
            size: 12,
            weight: .semibold,
            usage: "Valor financeiro auxiliar"
        )
        private static let moneyCaption1Token = Token(
            name: "moneyCaption1",
            family: .money,
            size: 11,
            weight: .regular,
            usage: "Valor financeiro mínimo"
        )
        private static let moneyCaption2Token = Token(
            name: "moneyCaption2",
            family: .money,
            size: 10,
            weight: .regular,
            usage: "Valor financeiro micro"
        )
        private static let codeToken = Token(
            name: "code",
            family: .code,
            size: 12,
            weight: .semibold,
            usage: "IDs, slugs e tokens"
        )

        public static let title1 = title1Token.font
        public static let title2 = title2Token.font
        public static let title3 = title3Token.font
        public static let headline = headlineToken.font
        public static let body = bodyToken.font
        public static let bodyEmphasis = bodyEmphasisToken.font
        public static let callout = calloutToken.font
        public static let calloutEmphasis = calloutEmphasisToken.font
        public static let subheadline = subheadlineToken.font
        public static let subheadlineEmphasis = subheadlineEmphasisToken.font
        public static let footnote = footnoteToken.font
        public static let footnoteEmphasis = footnoteEmphasisToken.font
        public static let caption1 = caption1Token.font
        public static let caption1Emphasis = caption1EmphasisToken.font
        public static let caption2 = caption2Token.font
        public static let caption2Emphasis = caption2EmphasisToken.font

        public static let moneyTitle1 = moneyTitle1Token.font
        public static let moneyTitle2 = moneyTitle2Token.font
        public static let moneyTitle3 = moneyTitle3Token.font
        public static let moneyHeadline = moneyHeadlineToken.font
        public static let moneyBody = moneyBodyToken.font
        public static let moneyBodyNSFont = NSFont.monospacedSystemFont(
            ofSize: moneyBodyToken.size,
            weight: moneyBodyToken.weight.nsFontWeight
        )
        public static let moneyCallout = moneyCalloutToken.font
        public static let moneySubheadline = moneySubheadlineToken.font
        public static let moneyFootnote = moneyFootnoteToken.font
        public static let moneyCaption1 = moneyCaption1Token.font
        public static let moneyCaption2 = moneyCaption2Token.font

        public static let code = codeToken.font

        public static let tokens: [Token] = [
            title1Token,
            title2Token,
            title3Token,
            headlineToken,
            bodyToken,
            bodyEmphasisToken,
            calloutToken,
            calloutEmphasisToken,
            subheadlineToken,
            subheadlineEmphasisToken,
            footnoteToken,
            footnoteEmphasisToken,
            caption1Token,
            caption1EmphasisToken,
            caption2Token,
            caption2EmphasisToken,
            moneyTitle1Token,
            moneyTitle2Token,
            moneyTitle3Token,
            moneyHeadlineToken,
            moneyBodyToken,
            moneyCalloutToken,
            moneySubheadlineToken,
            moneyFootnoteToken,
            moneyCaption1Token,
            moneyCaption2Token,
            codeToken,
        ]
    }

    public enum IconSize {
        public static let micro: CGFloat = 10
        public static let small: CGFloat = 12
        public static let medium: CGFloat = 20
        public static let large: CGFloat = 32
        public static let hero: CGFloat = 56

        public static func categoryGlyph(in bubbleSize: CGFloat) -> CGFloat {
            bubbleSize * 0.45
        }
    }

    public static func brandGradient(pressed: Bool = false) -> LinearGradient {
        LinearGradient(
            colors: [
                Palette.ink,
                pressed ? Palette.tealDeep : Palette.teal,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public struct GranaBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.Palette.backgroundStart,
                    Theme.Palette.backgroundEnd,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Theme.Palette.gold.opacity(0.28),
                    .clear,
                ],
                center: UnitPoint(x: 0.08, y: 0.08),
                startRadius: 0,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Theme.Palette.teal.opacity(0.20),
                    .clear,
                ],
                center: UnitPoint(x: 0.88, y: 0.0),
                startRadius: 0,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}

public enum GranaSurfaceProminence {
    case glass
    case solid
    case subtle
}

private struct GranaSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    let prominence: GranaSurfaceProminence
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shadow = surfaceShadow

        return content
            .background {
                surfaceFill
            }
            .overlay {
                if prominence == .solid {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: contrast == .increased ? 1.4 : 1)
                }
            }
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: 0,
                y: shadow.y
            )
    }

    @ViewBuilder
    private var surfaceFill: some View {
        switch prominence {
        case .glass where !reduceTransparency:
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.Palette.paper.opacity(0.64))
            }
        case .glass:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.Palette.paperSolid)
        case .solid:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.Palette.paperSolid.opacity(0.94))
        case .subtle:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.Palette.paper.opacity(0.72))
        }
    }

    private var borderColor: Color {
        contrast == .increased ? Theme.Palette.ink.opacity(0.28) : Theme.Palette.line
    }

    private var surfaceShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        switch prominence {
        case .glass:
            (Theme.Shadow.glassColor, 30, 14)
        case .subtle:
            (Theme.Shadow.cardColor, 14, 6)
        case .solid:
            (Theme.Shadow.rowColor, 7, 3)
        }
    }
}

public struct GranaPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.calloutEmphasis)
            .foregroundStyle(Theme.Palette.creamText)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(minHeight: 48)
            .background(
                Theme.brandGradient(pressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .shadow(color: Theme.Shadow.accentColor, radius: configuration.isPressed ? 8 : 17, y: 8)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

public struct GranaSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.calloutEmphasis)
            .foregroundStyle(Theme.Palette.ink)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(minHeight: 48)
            .background(
                configuration.isPressed
                    ? Theme.Palette.ink.opacity(0.11)
                    : Theme.Palette.soft,
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
    }
}

public struct GranaDestructiveButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.calloutEmphasis)
            .foregroundStyle(Theme.Palette.creamText)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(minHeight: 48)
            .background(
                configuration.isPressed
                    ? Theme.Palette.red.opacity(0.86)
                    : Theme.Palette.red,
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .shadow(color: Theme.Palette.red.opacity(0.20), radius: configuration.isPressed ? 8 : 14, y: 8)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

public extension View {
    func granaSurface(
        _ prominence: GranaSurfaceProminence = .subtle,
        cornerRadius: CGFloat = Theme.Radius.card
    ) -> some View {
        modifier(GranaSurfaceModifier(prominence: prominence, cornerRadius: cornerRadius))
    }
}

private struct ThemePreview: View {
    private let paletteSwatches: [(String, Color)] = [
        ("Background", Theme.Palette.background),
        ("Paper", Theme.Palette.paper),
        ("Ink", Theme.Palette.ink),
        ("Teal", Theme.Palette.teal),
        ("Gold", Theme.Palette.gold),
        ("Green", Theme.Palette.green),
        ("Red", Theme.Palette.red),
        ("Amber", Theme.Palette.amber),
    ]

    private let sampleTokens = Array(Theme.Typography.tokens.prefix(6))

    private let spacingTokens = Array(Theme.Spacing.tokens.prefix(5))

    var body: some View {
        AppUIPreviewSurface(title: "Theme") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Palette")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.ink)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120), spacing: Theme.Spacing.sm)],
                        alignment: .leading,
                        spacing: Theme.Spacing.sm
                    ) {
                        ForEach(paletteSwatches, id: \.0) { name, color in
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                    .fill(color)
                                    .frame(height: 56)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                            .strokeBorder(Theme.Palette.line, lineWidth: 1)
                                    }
                                Text(name)
                                    .font(Theme.Typography.caption1Emphasis)
                                    .foregroundStyle(Theme.Palette.ink)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Typography")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.ink)

                    ForEach(sampleTokens) { token in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(token.name)
                                .font(Theme.Typography.caption1Emphasis)
                                .foregroundStyle(Theme.Palette.tealDeep)
                            Text("Amostra visual do token \(token.name)")
                                .font(token.font)
                                .foregroundStyle(Theme.Palette.ink)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Spacing")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.ink)

                    ForEach(spacingTokens) { token in
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(token.name)
                                .font(Theme.Typography.caption1Emphasis)
                                .foregroundStyle(Theme.Palette.ink)
                                .frame(width: 72, alignment: .leading)
                            RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                                .fill(Theme.Palette.teal.opacity(0.18))
                                .frame(width: max(token.value * 6, 12), height: 12)
                            Text(token.displayValue)
                                .font(Theme.Typography.caption1)
                                .foregroundStyle(Theme.Palette.muted)
                        }
                    }
                }
            }
        }
    }
}

#Preview("AppUI.Theme") {
    ThemePreview()
}
