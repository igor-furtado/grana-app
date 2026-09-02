import SwiftUI

public enum Skeleton {
    public struct Line: View {
        private let width: CGFloat?
        private let height: CGFloat
        private let cornerRadius: CGFloat
        private let isAnimated: Bool

        public init(
            width: CGFloat? = nil,
            height: CGFloat = 13,
            cornerRadius: CGFloat? = nil,
            isAnimated: Bool = true
        ) {
            self.width = width
            self.height = height
            self.cornerRadius = cornerRadius ?? height / 2
            self.isAnimated = isAnimated
        }

        public var body: some View {
            Block(width: width, height: height, cornerRadius: cornerRadius, isAnimated: isAnimated)
        }
    }

    public struct Block: View {
        private let width: CGFloat?
        private let height: CGFloat
        private let cornerRadius: CGFloat
        private let isAnimated: Bool

        public init(
            width: CGFloat? = nil,
            height: CGFloat,
            cornerRadius: CGFloat = Theme.Radius.control,
            isAnimated: Bool = true
        ) {
            self.width = width
            self.height = height
            self.cornerRadius = cornerRadius
            self.isAnimated = isAnimated
        }

        public var body: some View {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.Palette.soft)
                .appSkeletonFrame(width: width, height: height)
                .overlay {
                    SkeletonShimmer(isAnimated: isAnimated)
                }
                .clipShape(shape)
                .accessibilityHidden(true)
        }
    }

    public struct Circle: View {
        private let size: CGFloat
        private let isAnimated: Bool

        public init(size: CGFloat, isAnimated: Bool = true) {
            self.size = size
            self.isAnimated = isAnimated
        }

        public var body: some View {
            SwiftUI.Circle()
                .fill(Theme.Palette.soft)
                .frame(width: size, height: size)
                .overlay {
                    SkeletonShimmer(isAnimated: isAnimated)
                }
                .clipShape(SwiftUI.Circle())
                .accessibilityHidden(true)
        }
    }
}

private extension View {
    @ViewBuilder
    func appSkeletonFrame(width: CGFloat?, height: CGFloat) -> some View {
        if let width, width.isInfinite {
            frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        } else {
            frame(width: width, height: height)
        }
    }
}

private struct SkeletonShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.85

    let isAnimated: Bool

    var body: some View {
        GeometryReader { geometry in
            if isAnimated, !reduceMotion {
                let width = max(geometry.size.width, 1)

                LinearGradient(
                    colors: [
                        .clear,
                        Theme.Palette.paper.opacity(0.72),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width * 0.55)
                .offset(x: width * phase)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .onAppear {
            guard isAnimated, !reduceMotion else { return }
            withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                phase = 1.35
            }
        }
    }
}

private struct SkeletonPreview: View {
    var body: some View {
        AppUIPreviewSurface(title: "Skeleton") {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                HStack(spacing: Theme.Spacing.sm) {
                    Skeleton.Circle(size: 40)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Skeleton.Line(width: 180)
                        Skeleton.Line(width: 92, height: 11)
                    }
                }

                Skeleton.Block(width: .infinity, height: 88, cornerRadius: Theme.Radius.card)
            }
            .frame(maxWidth: 360)
        }
    }
}

#Preview("AppUI.Skeleton") {
    SkeletonPreview()
}
