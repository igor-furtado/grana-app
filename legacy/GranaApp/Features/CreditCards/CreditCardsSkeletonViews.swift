import AppUI
import SwiftUI

struct CreditCardsLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
            CreditCardListSkeletonView()
            CreditCardStatementsSkeletonView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct CreditCardListSkeletonView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppUI.Theme.Spacing.md) {
                CreditCardSkeletonCard(isSelected: true)
                CreditCardSkeletonCard(isSelected: false)
            }
            .padding(.horizontal, AppUI.Theme.Spacing.md)
        }
    }
}

struct CreditCardStatementsSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.lg) {
                CreditCardStatementTimelineSkeletonView()
                CreditCardStatementCycleSkeletonView()
                StatementListSkeletonView(showsTitle: true)
            }
            .padding(AppUI.Theme.Spacing.xl)
        }
        .granaSurface(.subtle, cornerRadius: AppUI.Theme.Radius.hero)
    }
}

private struct CreditCardSkeletonCard: View {
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            HStack(alignment: .center, spacing: AppUI.Theme.Spacing.sm) {
                AppUI.Skeleton.Block(width: 40, height: 40, cornerRadius: AppUI.Theme.Radius.control)

                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                    AppUI.Skeleton.Line(width: 160, height: 15)
                    AppUI.Skeleton.Line(width: 92, height: 12)
                }

                Spacer(minLength: AppUI.Theme.Spacing.none)
            }

            HStack(alignment: .firstTextBaseline, spacing: AppUI.Theme.Spacing.md) {
                AppUI.Skeleton.Block(width: 96, height: 30, cornerRadius: AppUI.Theme.Radius.control)
                Spacer(minLength: AppUI.Theme.Spacing.none)
                AppUI.Skeleton.Block(width: 112, height: 30, cornerRadius: AppUI.Theme.Radius.control)
            }

            AppUI.Skeleton.Line(width: .infinity, height: 8)
        }
        .padding(AppUI.Theme.Spacing.md)
        .frame(width: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppUI.Theme.Radius.card, style: .continuous)
                .fill(AppUI.Theme.Palette.paperSolid.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppUI.Theme.Radius.card, style: .continuous)
                .strokeBorder(
                    isSelected ? AppUI.Theme.Palette.teal : AppUI.Theme.Palette.line,
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
    }
}

private struct CreditCardStatementTimelineSkeletonView: View {
    private let barHeights: [CGFloat] = [52, 84, 62, 106, 40, 74, 20]

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            HStack {
                Text("Faturas")
                    .font(AppUI.Theme.Typography.headline)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
                Spacer(minLength: AppUI.Theme.Spacing.none)
                HStack(spacing: AppUI.Theme.Spacing.xs) {
                    Circle()
                        .fill(AppUI.Theme.Palette.teal)
                        .frame(width: 9, height: 9)
                    Text("Carregando")
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                }
            }

            HStack(alignment: .bottom, spacing: AppUI.Theme.Spacing.md) {
                ForEach(Array(barHeights.enumerated()), id: \.offset) { _, height in
                    VStack(spacing: AppUI.Theme.Spacing.xxs) {
                        AppUI.Skeleton.Block(width: 18, height: height, cornerRadius: 5)
                        AppUI.Skeleton.Line(width: 32, height: 11)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140)
            .padding(.horizontal, AppUI.Theme.Spacing.xs)
            .padding(.vertical, AppUI.Theme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
        }
    }
}

private struct CreditCardStatementCycleSkeletonView: View {
    var body: some View {
        HStack(alignment: .top, spacing: AppUI.Theme.Spacing.sm) {
            cycleCard(isHighlighted: false)
                .opacity(0.75)
            cycleCard(isHighlighted: true)
            cycleCard(isHighlighted: false)
                .opacity(0.75)
        }
    }

    private func cycleCard(isHighlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            HStack(spacing: AppUI.Theme.Spacing.xs) {
                AppUI.Skeleton.Line(width: 44, height: 15)
                AppUI.Skeleton.Line(width: 62, height: 18)
                Spacer(minLength: AppUI.Theme.Spacing.none)
            }

            AppUI.Skeleton.Line(width: 136, height: 24)
            Divider()

            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                cycleDateRow(labelWidth: 124)
                cycleDateRow(labelWidth: 118)
            }
        }
        .padding(AppUI.Theme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppUI.Theme.Radius.card, style: .continuous)
                .fill(AppUI.Theme.Palette.paperSolid.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppUI.Theme.Radius.card, style: .continuous)
                .strokeBorder(
                    isHighlighted ? AppUI.Theme.Palette.teal : AppUI.Theme.Palette.line,
                    lineWidth: isHighlighted ? 1.5 : 1
                )
        )
    }

    private func cycleDateRow(labelWidth: CGFloat) -> some View {
        HStack {
            AppUI.Skeleton.Line(width: labelWidth, height: 13)
            Spacer(minLength: AppUI.Theme.Spacing.none)
            AppUI.Skeleton.Line(width: 44, height: 13)
        }
    }
}
