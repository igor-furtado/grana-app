import AppUI
import SwiftUI

struct StatementListSkeletonView: View {
    var showsTitle = false

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.none) {
            if showsTitle {
                statementListHeader
                Divider()
            }
            statementRow(descriptionWidth: 0.64)
            Divider()
            statementRow(descriptionWidth: 0.52)
        }
        .background(AppUI.Theme.Palette.paper.opacity(0.42))
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
    }

    private var statementListHeader: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            Text("Lançamentos")
                .font(AppUI.Theme.Typography.headline)
                .foregroundStyle(AppUI.Theme.Palette.ink)
            Spacer(minLength: AppUI.Theme.Spacing.none)
            AppUI.Skeleton.Line(width: 96, height: 15)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.md)
        .padding(.vertical, AppUI.Theme.Spacing.sm)
    }

    private func statementRow(descriptionWidth: CGFloat) -> some View {
        GeometryReader { geometry in
            HStack(spacing: AppUI.Theme.Spacing.sm) {
                AppUI.Skeleton.Line(width: geometry.size.width * descriptionWidth, height: 15)
                Spacer(minLength: AppUI.Theme.Spacing.none)
                AppUI.Skeleton.Line(width: 120, height: 15)
            }
            .padding(.horizontal, AppUI.Theme.Spacing.md)
            .padding(.vertical, AppUI.Theme.Spacing.xs)
        }
        .frame(height: 48)
    }
}
