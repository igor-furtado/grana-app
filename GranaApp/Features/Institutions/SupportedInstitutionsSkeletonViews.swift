import AppUI
import SwiftUI

struct SupportedInstitutionsSkeletonView: View {
    let columns: [GridItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
                AppUI.Skeleton.Line(width: 420, height: 40)

                LazyVGrid(columns: columns, spacing: AppUI.Theme.Spacing.md) {
                    ForEach(0 ..< 6, id: \.self) { index in
                        InstitutionCatalogCardSkeleton(index: index)
                    }
                }
            }
        }
    }
}

private struct InstitutionCatalogCardSkeleton: View {
    let index: Int

    var body: some View {
        HStack(spacing: AppUI.Theme.Spacing.md) {
            AppUI.Skeleton.Circle(size: 48)

            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
                AppUI.Skeleton.Line(width: index.isMultiple(of: 2) ? 132 : 172, height: 16)
                AppUI.Skeleton.Line(width: 92, height: 13)
                AppUI.Skeleton.Line(width: 148, height: 13)
                AppUI.Skeleton.Line(width: 188, height: 13)
            }

            Spacer(minLength: AppUI.Theme.Spacing.none)
        }
        .padding(AppUI.Theme.Spacing.md)
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
    }
}
