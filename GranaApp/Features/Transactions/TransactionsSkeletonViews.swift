import AppUI
import SwiftUI

struct TransactionsSkeletonView: View {
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
            ForEach(0 ..< 6, id: \.self) { row in
                Divider()
                transactionRow(index: row)
            }
            Spacer()
        }
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
    }

    private var filterBar: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Skeleton.Block(width: .infinity, height: 40, cornerRadius: AppUI.Theme.Radius.control)
            AppUI.Skeleton.Block(width: .infinity, height: 40, cornerRadius: AppUI.Theme.Radius.control)
            AppUI.Skeleton.Block(width: .infinity, height: 40, cornerRadius: AppUI.Theme.Radius.control)
            AppUI.Skeleton.Block(width: .infinity, height: 40, cornerRadius: AppUI.Theme.Radius.control)
            AppUI.Skeleton.Block(width: .infinity, height: 40, cornerRadius: AppUI.Theme.Radius.control)
        }
        .padding(AppUI.Theme.Spacing.sm)
    }

    private var tableHeader: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Skeleton.Line(width: 210, height: 13)
            AppUI.Skeleton.Line(width: 110, height: 13)
            AppUI.Skeleton.Line(width: 170, height: 13)
            Spacer(minLength: AppUI.Theme.Spacing.none)
            AppUI.Skeleton.Line(width: 140, height: 13)
            AppUI.Skeleton.Line(width: 80, height: 13)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.md)
        .padding(.vertical, AppUI.Theme.Spacing.xs)
    }

    private func transactionRow(index: Int) -> some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            HStack(spacing: AppUI.Theme.Spacing.sm) {
                AppUI.Skeleton.Circle(size: 24)
                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                    AppUI.Skeleton.Line(width: index.isMultiple(of: 2) ? 128 : 156, height: 15)
                    AppUI.Skeleton.Line(width: index.isMultiple(of: 2) ? 92 : 116, height: 12)
                }
                Spacer()
            }.frame(width: 210)
            AppUI.Skeleton.Line(width: 110, height: 15)
            AppUI.Skeleton.Line(width: 170, height: 15)
            AppUI.Skeleton.Line(width: index.isMultiple(of: 2) ? 112 : 148, height: 15)
            Spacer(minLength: AppUI.Theme.Spacing.none)
            AppUI.Skeleton.Line(width: 140, height: 15)
            AppUI.Skeleton.Line(width: 80, height: 24)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.md)
        .padding(.vertical, AppUI.Theme.Spacing.xs)
    }
}
