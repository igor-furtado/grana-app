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
        static let panel: CGFloat = 22
        static let hero: CGFloat = 32
        static let rail: CGFloat = 27
    }

    enum Shadow {
        static let glassColor = Color(red: 0.161, green: 0.129, blue: 0.086).opacity(0.14)
        static let cardColor = Palette.ink.opacity(0.07)
        static let rowColor = Palette.ink.opacity(0.04)
        static let accentColor = Palette.teal.opacity(0.22)
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
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(GranaTheme.Palette.creamText)
            .padding(.horizontal, 18)
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
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(GranaTheme.Palette.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(
                configuration.isPressed
                    ? GranaTheme.Palette.ink.opacity(0.11)
                    : GranaTheme.Palette.soft,
                in: RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
            )
    }
}

extension View {
    func granaSurface(
        _ prominence: GranaSurfaceProminence = .subtle,
        cornerRadius: CGFloat = GranaTheme.Radius.panel
    ) -> some View {
        modifier(GranaSurfaceModifier(prominence: prominence, cornerRadius: cornerRadius))
    }
}
