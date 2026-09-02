import AppUI
import ComposableArchitecture
import Foundation
import SwiftUI

struct CreditCardListView: View {
    @Bindable var store: StoreOf<CreditCardListFeature>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppUI.Theme.Spacing.md) {
                ForEach(store.visibleItems) { card in
                    CreditCardSelectorCard(
                        card: card,
                        isSelected: card.id == store.selectedCardId,
                        onSelect: { store.send(.cardTapped(card.id)) },
                        onEdit: { store.send(.editButtonTapped(card.id)) },
                        onToggleArchive: { store.send(.archiveButtonTapped(card.id)) },
                        onRequestDelete: { store.send(.deleteButtonTapped(card.id)) }
                    )
                }
            }
            .padding(.horizontal, AppUI.Theme.Spacing.md)
        }
    }
}

private struct CreditCardSelectorCard: View {
    let card: CreditCardListItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggleArchive: () -> Void
    let onRequestDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                cardContent
            }
            .buttonStyle(.plain)

            actionsMenu
                .padding(.top, AppUI.Theme.Spacing.md)
                .padding(.trailing, AppUI.Theme.Spacing.md)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            HStack(alignment: .center, spacing: AppUI.Theme.Spacing.sm) {
                if let institution = card.institution {
                    InstitutionIcon(kind: institution.kind, size: 40)
                } else {
                    placeholderIcon
                }

                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                    Text(bankName)
                        .font(AppUI.Theme.Typography.bodyEmphasis)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
                        .lineLimit(1)
                    HStack(spacing: AppUI.Theme.Spacing.xs) {
                        Text(maskedNumber)
                            .font(AppUI.Theme.Typography.code)
                            .foregroundStyle(AppUI.Theme.Palette.muted)
                        if card.account.archived {
                            Text("Arquivado")
                                .font(AppUI.Theme.Typography.caption2Emphasis)
                                .foregroundStyle(AppUI.Theme.Palette.muted)
                                .padding(.horizontal, AppUI.Theme.Spacing.xs)
                                .padding(.vertical, AppUI.Theme.Spacing.xxs)
                                .background(AppUI.Theme.Palette.soft, in: Capsule())
                        }
                    }
                }

                Spacer(minLength: 44)
            }

            HStack(alignment: .firstTextBaseline, spacing: AppUI.Theme.Spacing.md) {
                amountColumn(
                    title: "Usado",
                    value: card.currentBalance.magnitude,
                    alignment: .leading,
                    valueFont: AppUI.Theme.Typography.caption1Emphasis,
                    valueColor: AppUI.Theme.Palette.ink
                )
                Spacer(minLength: AppUI.Theme.Spacing.none)
                if let availableLimit {
                    amountColumn(
                        title: "Disponível",
                        value: availableLimit,
                        alignment: .trailing,
                        valueFont: AppUI.Theme.Typography.caption1,
                        valueColor: AppUI.Theme.Palette.muted
                    )
                }
            }

            if let limit = card.details?.creditLimit, limit > 0 {
                let progress = usagePercent(limit: limit)
                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
                    AppUI.UsageMeterBar(progress: progress)
                    HStack {
                        Text("Limite \(limit.formatted(.currency(code: card.account.currency)))")
                            .font(AppUI.Theme.Typography.caption1)
                            .foregroundStyle(AppUI.Theme.Palette.muted)
                        Spacer(minLength: AppUI.Theme.Spacing.none)
                        Text("\(Int(progress * 100))%")
                            .font(AppUI.Theme.Typography.caption1Emphasis)
                            .foregroundStyle(AppUI.Theme.Palette.ink)
                    }
                }
            }
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

    private var actionsMenu: some View {
        Menu {
            Button(action: onEdit) {
                Label("Editar", systemImage: AppUI.Icon.edit.systemImage)
            }
            Button(action: onToggleArchive) {
                Label(card.account.archived ? "Desarquivar" : "Arquivar", systemImage: AppUI.Icon.archive.systemImage)
            }
            Divider()
            Button(role: .destructive, action: onRequestDelete) {
                Label("Apagar", systemImage: AppUI.Icon.delete.systemImage)
                    .foregroundStyle(AppUI.Theme.Palette.red)
            }
        } label: {
            Image(systemName: AppUI.Icon.more.systemImage)
                .font(.system(size: AppUI.Theme.IconSize.small, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(AppUI.Theme.Palette.paper.opacity(0.95))
                )
                .overlay {
                    Circle().strokeBorder(AppUI.Theme.Palette.line, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuStyle(.button)
        .foregroundStyle(AppUI.Theme.Palette.muted)
        .help("Ações do cartão")
        .accessibilityLabel("Ações do cartão")
    }

    private var bankName: String {
        card.institution?.name ?? "Cartão"
    }

    private var maskedNumber: String {
        guard let last4 = card.details?.cardLastFour, last4.count == 4 else { return "Cartão" }
        return "•••• \(last4)"
    }

    private var availableLimit: Decimal? {
        guard let limit = card.details?.creditLimit, limit > 0 else { return nil }
        return max(0, limit - card.currentBalance.magnitude)
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: AppUI.Theme.Radius.control, style: .continuous)
            .fill(AppUI.Theme.Palette.soft)
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: AppUI.Icon.sidebarCreditCards.systemImage)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }
    }

    private func usagePercent(limit: Decimal) -> Double {
        let total = NSDecimalNumber(decimal: limit).doubleValue
        guard total > 0 else { return 0 }
        let used = NSDecimalNumber(decimal: card.currentBalance.magnitude).doubleValue
        return max(0, min(1, used / total))
    }

    private func amountColumn(
        title: String,
        value: Decimal,
        alignment: HorizontalAlignment,
        valueFont: Font,
        valueColor: Color
    ) -> some View {
        VStack(alignment: alignment, spacing: AppUI.Theme.Spacing.xxs) {
            Text(title)
                .font(AppUI.Theme.Typography.caption1)
                .foregroundStyle(AppUI.Theme.Palette.muted)
            Text(value.formatted(.currency(code: card.account.currency)))
                .font(valueFont)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
