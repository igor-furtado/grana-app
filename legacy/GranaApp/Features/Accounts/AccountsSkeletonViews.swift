import AppUI
import SwiftUI

struct AccountListSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.none) {
            tableShell
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
            Spacer()
        }
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
    }

    private var filterBar: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Skeleton.Block(width: 220, height: 40, cornerRadius: AppUI.Theme.Radius.control)
            AppUI.Skeleton.Block(width: .infinity, height: 40, cornerRadius: AppUI.Theme.Radius.control)
        }
        .padding(AppUI.Theme.Spacing.sm)
    }

    private var tableHeader: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Skeleton.Line(width: 210, height: 13)
            AppUI.Skeleton.Line(width: 210, height: 13)
            Spacer(minLength: AppUI.Theme.Spacing.none)
            AppUI.Skeleton.Line(width: 60, height: 13)
            AppUI.Skeleton.Line(width: 60, height: 13)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.md)
        .padding(.vertical, AppUI.Theme.Spacing.xs)
    }

    private func accountRow(index: Int) -> some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            HStack(spacing: AppUI.Theme.Spacing.sm) {
                AppUI.Skeleton.Circle(size: 24)
                AppUI.Skeleton.Line(width: index.isMultiple(of: 2) ? 116 : 148, height: 15)
                Spacer()
            }.frame(width: 210)
            HStack(spacing: AppUI.Theme.Spacing.sm) {
                AppUI.Skeleton.Line(width: index.isMultiple(of: 2) ? 136 : 128, height: 15)
                Spacer()
            }.frame(width: 210)
            AppUI.Skeleton.Line(width: index.isMultiple(of: 2) ? 116 : 148, height: 15)
            Spacer(minLength: AppUI.Theme.Spacing.none)
            AppUI.Skeleton.Line(width: 60, height: 15)
            AppUI.Skeleton.Line(width: 60, height: 15)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.md)
        .padding(.vertical, AppUI.Theme.Spacing.xs)
    }
}
