import SwiftUI

extension AppUI {
    struct UsageMeterBar: View {
        struct Threshold {
            let upperBound: Double
            let fill: Color
        }

        static let defaultThresholds: [Threshold] = [
            .init(upperBound: 0.30, fill: .success),
            .init(upperBound: 0.70, fill: .warning),
        ]

        private let progress: Double
        private let fill: Color
        private let track: Color
        private let height: CGFloat
        private let cornerRadius: CGFloat
        private let minimumFillWidth: CGFloat

        init(
            progress: Double,
            fill: Color,
            track: Color = GranaTheme.Palette.soft,
            height: CGFloat = 8,
            cornerRadius: CGFloat = 999,
            minimumFillWidth: CGFloat = 6
        ) {
            self.progress = Self.clamped(progress)
            self.fill = fill
            self.track = track
            self.height = height
            self.cornerRadius = cornerRadius
            self.minimumFillWidth = minimumFillWidth
        }

        init(
            progress: Double,
            thresholds: [Threshold] = Self.defaultThresholds,
            fallbackFill: Color = .danger,
            track: Color = GranaTheme.Palette.soft,
            height: CGFloat = 8,
            cornerRadius: CGFloat = 999,
            minimumFillWidth: CGFloat = 6
        ) {
            let clampedProgress = Self.clamped(progress)
            self.init(
                progress: clampedProgress,
                fill: Self.fill(
                    for: clampedProgress,
                    thresholds: thresholds,
                    fallbackFill: fallbackFill
                ),
                track: track,
                height: height,
                cornerRadius: cornerRadius,
                minimumFillWidth: minimumFillWidth
            )
        }

        var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(track)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fill)
                        .frame(width: max(minimumFillWidth, geometry.size.width * progress))
                }
            }
            .frame(height: height)
        }

        static func fill(
            for progress: Double,
            thresholds: [Threshold] = defaultThresholds,
            fallbackFill: Color = .danger
        ) -> Color {
            let clampedProgress = clamped(progress)
            return thresholds.first(where: { clampedProgress < $0.upperBound })?.fill ?? fallbackFill
        }

        private static func clamped(_ progress: Double) -> Double {
            max(0, min(1, progress))
        }
    }
}
