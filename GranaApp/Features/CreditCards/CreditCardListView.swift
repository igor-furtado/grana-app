import ComposableArchitecture
import Foundation
import SwiftUI

struct CreditCardListView: View {
    @Bindable var store: StoreOf<CreditCardListFeature>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GranaTheme.Spacing.md) {
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
            .padding(.horizontal, GranaTheme.Spacing.md)
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
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                HStack(alignment: .center, spacing: GranaTheme.Spacing.sm) {
                    if let institution = card.institution {
                        InstitutionIcon(kind: institution.kind, size: 40)
                    } else {
                        placeholderIcon
                    }

                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                        Text(bankName)
                            .font(GranaTheme.Typography.bodyEmphasis)
                            .foregroundStyle(GranaTheme.Palette.ink)
                            .lineLimit(1)
                        Text(maskedNumber)
                            .font(GranaTheme.Typography.code)
                            .foregroundStyle(GranaTheme.Palette.muted)
                    }

                    Spacer(minLength: GranaTheme.Spacing.none)

                    if card.account.archived {
                        Text("Arquivado")
                            .font(GranaTheme.Typography.caption2Emphasis)
                            .foregroundStyle(GranaTheme.Palette.muted)
                            .padding(.horizontal, GranaTheme.Spacing.xs)
                            .padding(.vertical, GranaTheme.Spacing.xxs)
                            .background(GranaTheme.Palette.soft, in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text("Fatura atual")
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)
                    Text(card.currentBalance.magnitude.formatted(.currency(code: card.account.currency)))
                        .font(GranaTheme.Typography.moneyHeadline)
                        .foregroundStyle(GranaTheme.Palette.ink)
                }

                if let limit = card.details?.creditLimit, limit > 0 {
                    let progress = usagePercent(limit: limit)
                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                        AppUI.UsageMeterBar(progress: progress)
                        HStack {
                            Text("Limite \(limit.formatted(.currency(code: card.account.currency)))")
                                .font(GranaTheme.Typography.caption1)
                                .foregroundStyle(GranaTheme.Palette.muted)
                            Spacer(minLength: GranaTheme.Spacing.none)
                            Text("\(Int(progress * 100))%")
                                .font(GranaTheme.Typography.caption1Emphasis)
                                .foregroundStyle(GranaTheme.Palette.ink)
                        }
                    }
                }
            }
            .padding(GranaTheme.Spacing.lg)
            .frame(width: 280, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
                    .fill(GranaTheme.Palette.paperSolid.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? GranaTheme.Palette.teal : GranaTheme.Palette.line,
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
        RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
            .fill(GranaTheme.Palette.soft)
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: AppIcon.sidebarCreditCards.systemImage)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
    }

    private func usagePercent(limit: Decimal) -> Double {
        let total = NSDecimalNumber(decimal: limit).doubleValue
        guard total > 0 else { return 0 }
        let used = NSDecimalNumber(decimal: card.currentBalance.magnitude).doubleValue
        return max(0, min(1, used / total))
    }
}
