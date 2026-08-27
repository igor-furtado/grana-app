import ComposableArchitecture
import SwiftUI

struct CreditCardsView: View {
    @Bindable var store: StoreOf<CreditCardsFeature>

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            FeatureScreenHeader(
                title: "Cartões de crédito",
                subtitle: store.list.summarySubtitle
            ) {
                HStack(spacing: GranaTheme.Spacing.sm) {
                    Button {
                        store.send(.list(.addButtonTapped))
                    } label: {
                        Label("Novo cartão", systemImage: AppIcon.add.systemImage)
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())

                    if store.list.hasArchivedCard {
                        Menu {
                            Toggle("Mostrar arquivados", isOn: $store.list.showArchived)
                        } label: {
                            Label("Mais", systemImage: AppIcon.more.systemImage)
                        }
                        .buttonStyle(GranaSecondaryButtonStyle())
                    }
                }
            }

            Group {
                if store.list.visibleItems.isEmpty, !store.isLoading {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let statementsStore = store.scope(state: \.statements, action: \.statements) {
                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                        CreditCardListView(store: store.scope(state: \.list, action: \.list))
                        CreditCardStatementsView(store: statementsStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    placeholderDetail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .granaPagePadding()
        .toolbar(.hidden, for: .windowToolbar)
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).form
        ) { formStore in
            CreditCardFormView(store: formStore)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).archive
        ) { archiveStore in
            CreditCardArchiveView(store: archiveStore)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).delete
        ) { deleteStore in
            CreditCardDeleteView(store: deleteStore)
        }
        .task {
            await store.send(.task).finish()
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            "Sem cartões por aqui",
            icon: .sidebarCreditCards,
            description: "Cadastre os cartões de crédito que você usa pra acompanhar as faturas, fechamento, vencimento e limite."
        ) {
            Button {
                store.send(.list(.addButtonTapped))
            } label: {
                Label("Cadastrar primeiro cartão", systemImage: AppIcon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
        }
    }

    private var placeholderDetail: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            ProgressView()
            Text("Carregando cartões…")
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(GranaTheme.Spacing.xxxl)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
    }
}

private struct CreditCardListView: View {
    @Bindable var store: StoreOf<CreditCardListFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            HStack {
                Text("Seus cartões")
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.ink)
                Spacer(minLength: GranaTheme.Spacing.none)
                Text("\(store.visibleCount) \(store.visibleCount == 1 ? "item" : "itens")")
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
            .padding(.horizontal, GranaTheme.Spacing.md)
            .padding(.top, GranaTheme.Spacing.md)

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
                .padding(.bottom, GranaTheme.Spacing.md)
            }
        }
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
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
                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                        CreditCardUsageBar(
                            percent: usagePercent(limit: limit),
                            tint: barTint(limit: limit)
                        )
                        HStack {
                            Text("Limite \(limit.formatted(.currency(code: card.account.currency)))")
                                .font(GranaTheme.Typography.caption1)
                                .foregroundStyle(GranaTheme.Palette.muted)
                            Spacer(minLength: GranaTheme.Spacing.none)
                            Text("\(Int(usagePercent(limit: limit) * 100))%")
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

    private func barTint(limit: Decimal) -> Color {
        let percent = usagePercent(limit: limit)
        if percent < 0.30 { return .success }
        if percent < 0.70 { return .warning }
        return .danger
    }

    private func usagePercent(limit: Decimal) -> Double {
        let total = NSDecimalNumber(decimal: limit).doubleValue
        guard total > 0 else { return 0 }
        let used = NSDecimalNumber(decimal: card.currentBalance.magnitude).doubleValue
        return max(0, min(1, used / total))
    }
}

private struct CreditCardUsageBar: View {
    let percent: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(GranaTheme.Palette.soft)
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(tint)
                    .frame(width: max(6, geometry.size.width * percent))
            }
        }
        .frame(height: 8)
    }
}
