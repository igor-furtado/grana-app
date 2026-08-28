import SwiftUI

struct SideDrawer<Content: View>: View {
    let width: CGFloat
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        width: CGFloat = 520,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.width = width
        self.onDismiss = onDismiss
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                scrim

                content()
                    .frame(width: min(width, max(320, proxy.size.width - GranaTheme.Spacing.xl)))
                    .frame(maxHeight: .infinity)
                    .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
                    .padding(.vertical, GranaTheme.Spacing.md)
                    .padding(.trailing, GranaTheme.Spacing.md)
                    .transition(drawerTransition)
                    .allowsHitTesting(true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(drawerAnimation, value: reduceMotion)
        }
    }

    private var scrim: some View {
        Rectangle()
            .fill(GranaTheme.Palette.ink.opacity(0.28))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
    }

    private var drawerTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }

    private var drawerAnimation: Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.35, bounce: 0.12)
    }
}
