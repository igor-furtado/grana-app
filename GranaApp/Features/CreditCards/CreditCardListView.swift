import ComposableArchitecture
import Foundation
import SwiftUI
import AppUI

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
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
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
                        Text(maskedNumber)
                            .font(AppUI.Theme.Typography.code)
                            .foregroundStyle(AppUI.Theme.Palette.muted)
                    }

                    Spacer(minLength: AppUI.Theme.Spacing.none)

                    if card.account.archived {
                        Text("Arquivado")
                            .font(AppUI.Theme.Typography.caption2Emphasis)
                            .foregroundStyle(AppUI.Theme.Palette.muted)
                            .padding(.horizontal, AppUI.Theme.Spacing.xs)
                            .padding(.vertical, AppUI.Theme.Spacing.xxs)
                            .background(AppUI.Theme.Palette.soft, in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                    Text("Fatura atual")
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                    Text(card.currentBalance.magnitude.formatted(.currency(code: card.account.currency)))
                        .font(AppUI.Theme.Typography.moneyHeadline)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
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
            .padding(AppUI.Theme.Spacing.lg)
            .frame(width: 280, alignment: .leading)
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
        .buttonStyle(.plain)
        .contextMenu {
            Button("Editar", action: onEdit)
            Button(card.account.archived ? "Desarquivar" : "Arquivar", action: onToggleArchive)
            Divider()
            Button("Apagar", role: .destructive, action: onRequestDelete)
        }
    }

    private var bankName: String {
        card.institution?.name ?? "Cartão"
    }

    private var maskedNumber: String {
        guard let last4 = card.details?.cardLastFour, last4.count == 4 else { return "Cartão" }
        return "•••• \(last4)"
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
}
