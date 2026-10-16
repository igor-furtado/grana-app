import AppUI
import SwiftUI

struct SupportedInstitutionsSkeletonView: View {
    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.none) {
            header

            ForEach(0 ..< 7, id: \.self) { index in
                row(index: index)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(AppUI.Theme.Palette.line)
                            .frame(height: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppUI.Theme.Palette.paper.opacity(0.42))
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: AppUI.Theme.Radius.card, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: AppUI.Theme.Spacing.lg) {
            AppUI.Skeleton.Line(width: 120, height: 13)
            AppUI.Skeleton.Line(width: 72, height: 13)
            AppUI.Skeleton.Line(width: 54, height: 13)
            AppUI.Skeleton.Line(width: 86, height: 13)
            Spacer(minLength: AppUI.Theme.Spacing.none)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.md)
        .padding(.vertical, AppUI.Theme.Spacing.sm)
        .background(AppUI.Theme.Palette.paper.opacity(0.58))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppUI.Theme.Palette.line)
                .frame(height: 1)
        }
    }

    private func row(index: Int) -> some View {
        HStack(spacing: AppUI.Theme.Spacing.lg) {
            HStack(spacing: AppUI.Theme.Spacing.sm) {
                AppUI.Skeleton.Circle(size: 24)
                AppUI.Skeleton.Line(width: index.isMultiple(of: 2) ? 144 : 184, height: 15)
            }
            .frame(width: 260, alignment: .leading)

            AppUI.Skeleton.Line(width: 44, height: 14)
                .frame(width: 90, alignment: .leading)

            badgeGroup(widths: index.isMultiple(of: 2) ? [112, 96] : [96])
                .frame(width: 240, alignment: .leading)

            badgeGroup(widths: index.isMultiple(of: 3) ? [48] : [128, 48])

            Spacer(minLength: AppUI.Theme.Spacing.none)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.md)
        .padding(.vertical, AppUI.Theme.Spacing.sm)
    }

    private func badgeGroup(widths: [CGFloat]) -> some View {
        HStack(spacing: AppUI.Theme.Spacing.xs) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                AppUI.Skeleton.Line(width: width, height: 22)
                    .clipShape(Capsule())
            }
        }
    }
}
