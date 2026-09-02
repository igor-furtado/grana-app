import AppUI
import SwiftUI

struct CategoriesSkeletonView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: AppUI.Theme.Spacing.sm, alignment: .top),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxl) {
                categorySectionSkeleton(titleWidth: 92)
                categorySectionSkeleton(titleWidth: 104)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func categorySectionSkeleton(titleWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
            HStack(spacing: AppUI.Theme.Spacing.xs) {
                AppUI.Skeleton.Circle(size: 10)
                AppUI.Skeleton.Line(width: titleWidth, height: 22)
                AppUI.Skeleton.Line(width: 28, height: 15)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
                ForEach(0 ..< 6, id: \.self) { index in
                    CategoryCardSkeleton(isSelected: index == 0)
                }
            }
        }
    }
}

struct CategoryInspectorSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.lg) {
                AppUI.Skeleton.Block(width: .infinity, height: 160, cornerRadius: 16)

                VStack(alignment: .center, spacing: AppUI.Theme.Spacing.xxs) {
                    AppUI.Skeleton.Line(width: 148, height: 22)
                    AppUI.Skeleton.Line(width: 84, height: 15)
                }
                .frame(maxWidth: .infinity)

                Divider()

                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
                    AppUI.Skeleton.Line(width: 132, height: 16)
                    AppUI.Skeleton.Line(width: .infinity, height: 15)
                    AppUI.Skeleton.Line(width: 180, height: 15)
                    AppUI.Skeleton.Line(width: 128, height: 15)
                }
                .padding(AppUI.Theme.Spacing.md)
                .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.control)
            }
            .padding(AppUI.Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct CategoryCardSkeleton: View {
    let isSelected: Bool

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Skeleton.Circle(size: 42)
                .frame(maxWidth: .infinity)
            AppUI.Skeleton.Line(width: 96, height: 15)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 124)
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: AppUI.Theme.Radius.card, style: .continuous)
                .stroke(AppUI.Theme.Palette.teal, lineWidth: 2)
                .opacity(isSelected ? 1 : 0)
        )
    }
}
