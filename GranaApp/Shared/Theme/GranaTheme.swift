import SwiftUI

enum GranaTheme {
    enum Palette {
        static let background = Color(red: 0.957, green: 0.941, blue: 0.910)
        static let backgroundStart = Color(red: 0.973, green: 0.953, blue: 0.910)
        static let backgroundEnd = Color(red: 0.929, green: 0.957, blue: 0.937)
        static let ink = Color(red: 0.090, green: 0.137, blue: 0.122)
        static let paper = Color(red: 1.000, green: 0.988, blue: 0.961)
        static let paperSolid = Color(red: 1.000, green: 0.980, blue: 0.941)
        static let teal = Color(red: 0.067, green: 0.478, blue: 0.408)
        static let tealDeep = Color(red: 0.047, green: 0.373, blue: 0.325)
        static let green = Color(red: 0.078, green: 0.486, blue: 0.337)
        static let red = Color(red: 0.788, green: 0.255, blue: 0.227)
        static let amber = Color(red: 0.847, green: 0.569, blue: 0.169)
        static let gold = Color(red: 0.929, green: 0.722, blue: 0.373)
        static let creamText = Color(red: 1.000, green: 0.976, blue: 0.929)

        static var muted: Color {
            ink.opacity(0.62)
        }

        static var soft: Color {
            ink.opacity(0.07)
        }

        static var line: Color {
            ink.opacity(0.13)
        }
    }

    enum Radius {
        static let control: CGFloat = 15
        static let card: CGFloat = 22
        static let hero: CGFloat = 32
        static let rail: CGFloat = 27
    }

    enum Shadow {
        static let glassColor = Color(red: 0.161, green: 0.129, blue: 0.086).opacity(0.14)
        static let cardColor = Palette.ink.opacity(0.07)
        static let rowColor = Palette.ink.opacity(0.04)
        static let accentColor = Palette.teal.opacity(0.22)
    }

    enum Layout {
        static let pageInsets = EdgeInsets(
            top: GranaTheme.Spacing.none,
            leading: GranaTheme.Spacing.none,
            bottom: GranaTheme.Spacing.lg,
            trailing: GranaTheme.Spacing.lg
        )
        static let railInsets = EdgeInsets(
            top: GranaTheme.Spacing.none,
            leading: GranaTheme.Spacing.lg,
            bottom: GranaTheme.Spacing.lg,
            trailing: GranaTheme.Spacing.lg
        )
    }

    enum Typography {
        struct Token: Identifiable {
            let name: String
            let family: Family
            let size: CGFloat
            let weight: Weight
            let usage: String

            var id: String {
                name
            }

            var category: String {
                family.category
            }

            var font: Font {
                Font.system(size: size, weight: weight.fontWeight, design: family.design)
            }

            var value: String {
                "\(family.displayName) \(Int(size)) \(weight.displayName)"
            }
        }

        enum Family {
            case text
            case money
            case code

            var category: String {
                switch self {
                case .text:
                    "Texto"
                case .money:
                    "Dinheiro"
                case .code:
                    "Código"
                }
            }

            var design: Font.Design {
                switch self {
                case .text:
                    .default
                case .money, .code:
                    .monospaced
                }
            }

            var displayName: String {
                switch self {
                case .text:
                    "SF Pro"
                case .money, .code:
                    "SF Mono"
                }
            }
        }

        enum Weight {
            case regular
            case medium
            case semibold
            case bold
            case black

            var fontWeight: Font.Weight {
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

            var displayName: String {
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

        private static let largeTitleToken = Token(
            name: "largeTitle",
            family: .text,
            size: 54,
            weight: .black,
            usage: "Marca, login e estados vazios"
        )
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
        private static let moneyLargeTitleToken = Token(
            name: "moneyLargeTitle",
            family: .money,
            size: 54,
            weight: .black,
            usage: "Valor financeiro hero"
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

        static let largeTitle = largeTitleToken.font
        static let title1 = title1Token.font
        static let title2 = title2Token.font
        static let title3 = title3Token.font
        static let headline = headlineToken.font
        static let body = bodyToken.font
        static let bodyEmphasis = bodyEmphasisToken.font
        static let callout = calloutToken.font
        static let calloutEmphasis = calloutEmphasisToken.font
        static let subheadline = subheadlineToken.font
        static let subheadlineEmphasis = subheadlineEmphasisToken.font
        static let footnote = footnoteToken.font
        static let footnoteEmphasis = footnoteEmphasisToken.font
        static let caption1 = caption1Token.font
        static let caption1Emphasis = caption1EmphasisToken.font
        static let caption2 = caption2Token.font
        static let caption2Emphasis = caption2EmphasisToken.font

        static let moneyLargeTitle = moneyLargeTitleToken.font
        static let moneyTitle1 = moneyTitle1Token.font
        static let moneyTitle2 = moneyTitle2Token.font
        static let moneyTitle3 = moneyTitle3Token.font
        static let moneyHeadline = moneyHeadlineToken.font
        static let moneyBody = moneyBodyToken.font
        static let moneyCallout = moneyCalloutToken.font
        static let moneySubheadline = moneySubheadlineToken.font
        static let moneyFootnote = moneyFootnoteToken.font
        static let moneyCaption1 = moneyCaption1Token.font
        static let moneyCaption2 = moneyCaption2Token.font

        static let code = codeToken.font

        static let tokens: [Token] = [
            largeTitleToken,
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
            moneyLargeTitleToken,
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

    enum IconSize {
        static let micro: CGFloat = 10
        static let small: CGFloat = 12
        static let medium: CGFloat = 20
        static let large: CGFloat = 32
        static let hero: CGFloat = 56

        static func categoryGlyph(in bubbleSize: CGFloat) -> CGFloat {
            bubbleSize * 0.45
        }
    }

    static func brandGradient(pressed: Bool = false) -> LinearGradient {
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

struct GranaBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    GranaTheme.Palette.backgroundStart,
                    GranaTheme.Palette.backgroundEnd,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    GranaTheme.Palette.gold.opacity(0.28),
                    .clear,
                ],
                center: UnitPoint(x: 0.08, y: 0.08),
                startRadius: 0,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    GranaTheme.Palette.teal.opacity(0.20),
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

enum GranaSurfaceProminence {
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
                    .fill(GranaTheme.Palette.paper.opacity(0.64))
            }
        case .glass:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(GranaTheme.Palette.paperSolid)
        case .solid:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(GranaTheme.Palette.paperSolid.opacity(0.94))
        case .subtle:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(GranaTheme.Palette.paper.opacity(0.72))
        }
    }

    private var borderColor: Color {
        contrast == .increased ? GranaTheme.Palette.ink.opacity(0.28) : GranaTheme.Palette.line
    }

    private var surfaceShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        switch prominence {
        case .glass:
            (GranaTheme.Shadow.glassColor, 30, 14)
        case .subtle:
            (GranaTheme.Shadow.cardColor, 14, 6)
        case .solid:
            (GranaTheme.Shadow.rowColor, 7, 3)
        }
    }
}

struct GranaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GranaTheme.Typography.calloutEmphasis)
            .foregroundStyle(GranaTheme.Palette.creamText)
            .padding(.horizontal, GranaTheme.Spacing.lg)
            .frame(minHeight: 48)
            .background(
                GranaTheme.brandGradient(pressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
            )
            .shadow(color: GranaTheme.Shadow.accentColor, radius: configuration.isPressed ? 8 : 17, y: 8)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct GranaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GranaTheme.Typography.calloutEmphasis)
            .foregroundStyle(GranaTheme.Palette.ink)
            .padding(.horizontal, GranaTheme.Spacing.lg)
            .frame(minHeight: 48)
            .background(
                configuration.isPressed
                    ? GranaTheme.Palette.ink.opacity(0.11)
                    : GranaTheme.Palette.soft,
                in: RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
            )
    }
}

struct GranaDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GranaTheme.Typography.calloutEmphasis)
            .foregroundStyle(GranaTheme.Palette.creamText)
            .padding(.horizontal, GranaTheme.Spacing.lg)
            .frame(minHeight: 48)
            .background(
                configuration.isPressed
                    ? GranaTheme.Palette.red.opacity(0.86)
                    : GranaTheme.Palette.red,
                in: RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
            )
            .shadow(color: GranaTheme.Palette.red.opacity(0.20), radius: configuration.isPressed ? 8 : 14, y: 8)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

extension View {
    func granaSurface(
        _ prominence: GranaSurfaceProminence = .subtle,
        cornerRadius: CGFloat = GranaTheme.Radius.card
    ) -> some View {
        modifier(GranaSurfaceModifier(prominence: prominence, cornerRadius: cornerRadius))
    }
}
