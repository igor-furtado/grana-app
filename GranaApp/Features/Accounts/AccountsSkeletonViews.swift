import AppUI
import SwiftUI

struct AccountListSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.none) {
            panelHeader
            tableShell
                .padding(AppUI.Theme.Spacing.md)
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .center, spacing: AppUI.Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                AppUI.Skeleton.Line(width: 184, height: 18)
                AppUI.Skeleton.Line(width: 420, height: 13)
            }

            Spacer(minLength: AppUI.Theme.Spacing.none)

            AppUI.Skeleton.Block(width: 76, height: 28, cornerRadius: 14)
        }
        .padding(AppUI.Theme.Spacing.md)
        .background(AppUI.Theme.Palette.paper.opacity(0.58))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppUI.Theme.Palette.line)
                .frame(height: 1)
        }
    }

    private var tableShell: some View {
        VStack(spacing: AppUI.Theme.Spacing.none) {
            filterBar
            Divider()
            tableHeader
            ForEach(0 ..< 4, id: \.self) { row in
                Divider()
                accountRow(index: row)
            }
        }
        .background(AppUI.Theme.Palette.paper.opacity(0.42))
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
    }

    private var filterBar: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Skeleton.Block(width: 220, height: 40, cornerRadius: AppUI.Theme.Radius.control)
            AppUI.Skeleton.Block(width: .infinity, height: 40, cornerRadius: AppUI.Theme.Radius.control)
            AppUI.Skeleton.Block(width: 180, height: 40, cornerRadius: AppUI.Theme.Radius.control)
        }
        .padding(AppUI.Theme.Spacing.sm)
    }

    private var tableHeader: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Skeleton.Line(width: 96, height: 13)
            AppUI.Skeleton.Line(width: 72, height: 13)
            Spacer(minLength: AppUI.Theme.Spacing.none)
            AppUI.Skeleton.Line(width: 56, height: 13)
            AppUI.Skeleton.Line(width: 52, height: 13)
            AppUI.Skeleton.Line(width: 64, height: 13)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.md)
        .padding(.vertical, AppUI.Theme.Spacing.xs)
    }

    private func accountRow(index: Int) -> some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Skeleton.Circle(size: 24)
            AppUI.Skeleton.Line(width: index.isMultiple(of: 2) ? 116 : 148, height: 15)
            AppUI.Skeleton.Line(width: index.isMultiple(of: 2) ? 164 : 208, height: 15)
            Spacer(minLength: AppUI.Theme.Spacing.none)
            AppUI.Skeleton.Line(width: 104, height: 15)
            AppUI.Skeleton.Line(width: 64, height: 15)
            AppUI.Skeleton.Line(width: 92, height: 24)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.md)
        .padding(.vertical, AppUI.Theme.Spacing.xs)
    }
}
