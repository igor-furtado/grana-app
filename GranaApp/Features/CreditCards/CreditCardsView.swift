import Foundation
import SwiftUI

struct CreditCardsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: AccountStore?
    @State private var selectedCardId: UUID?
    @State private var formMode: FormMode?
    @State private var showArchived = false
    @State private var showDeleteConfirm = false

    enum FormMode: Identifiable {
        case create
        case edit(Account)

        var id: String {
            switch self {
            case .create:
                return "create"
            case let .edit(account):
                return "edit-\(account.id.uuidString)"
            }
        }
    }

    var body: some View {
        Group {
            if let store {
                content(store: store)
                    .task { await store.load() }
            } else {
                ProgressView()
                    .task { store = AccountStore(container: environment.container) }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
    }

    private func content(store: AccountStore) -> some View {
        let visibleCards = visible(store: store)
        return VStack(spacing: GranaTheme.Spacing.sm) {
            header(store: store, visibleCount: visibleCards.count)

            Group {
                if visibleCards.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    stackedContent(store: store, cards: visibleCards)
                }
            }
        }
        .granaPagePadding()
        .sheet(item: $formMode) { mode in
            AccountFormView(
                existing: editingAccount(from: mode),
                lockedType: .creditCard,
                onCancel: { formMode = nil },
                onSaved: { formMode = nil }
            )
            .environment(store)
        }
        .confirmationDialog(
            "Apagar cartão?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Apagar", role: .destructive) {
                guard let id = selectedCardId else { return }
                Task {
                    do {
                        try await store.delete(id: id)
                    } catch {
                        NoticeCenter.shared.report(error)
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(
                "O cartão só será apagado se não houver transações, faturas ou lotes de importação vinculados."
            )
        }
        .onChange(of: visibleCards.map(\.id)) { _, ids in
            reconcileSelection(visibleIds: ids)
        }
        .onAppear {
            reconcileSelection(visibleIds: visibleCards.map(\.id))
        }
    }

    private func header(store: AccountStore, visibleCount: Int) -> some View {
        FeatureScreenHeader(
            title: "Cartões de crédito",
            subtitle: cardsSubtitle(store: store, visibleCount: visibleCount)
        ) {
            HStack(spacing: GranaTheme.Spacing.sm) {
                Button {
                    formMode = .create
                } label: {
                    Label("Novo cartão", systemImage: AppIcon.add.systemImage)
                }
                .buttonStyle(GranaPrimaryButtonStyle())

                if hasArchivedCard {
                    Menu {
                        Toggle("Mostrar arquivados", isOn: $showArchived)
                    } label: {
                        Label("Mais", systemImage: AppIcon.more.systemImage)
                    }
                    .buttonStyle(GranaSecondaryButtonStyle())
                }
            }
        }
    }

    private func stackedContent(store: AccountStore, cards: [Account]) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            cardSelector(store: store, cards: cards)

            if let selectedId = selectedCardId,
               let account = cards.first(where: { $0.id == selectedId })
            {
                CreditCardDetailView(account: account, store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholderDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func cardSelector(store: AccountStore, cards: [Account]) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            HStack {
                Text("Seus cartões")
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.ink)
                Spacer(minLength: GranaTheme.Spacing.none)
                Text("\(cards.count) \(cards.count == 1 ? "item" : "itens")")
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
            .padding(.horizontal, GranaTheme.Spacing.md)
            .padding(.top, GranaTheme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GranaTheme.Spacing.md) {
                    ForEach(cards) { account in
                        CreditCardSelectorCard(
                            account: account,
                            institution: store.institution(forAccount: account),
                            details: store.creditCard(for: account.id),
                            currentBalance: store.currentBalance(for: account),
                            isSelected: account.id == selectedCardId,
                            onSelect: { selectedCardId = account.id },
                            onEdit: {
                                selectedCardId = account.id
                                formMode = .edit(account)
                            },
                            onToggleArchive: {
                                selectedCardId = account.id
                                Task {
                                    do {
                                        try await store.setArchived(account, archived: !account.archived)
                                    } catch {
                                        NoticeCenter.shared.report(error)
                                    }
                                }
                            },
                            onRequestDelete: {
                                selectedCardId = account.id
                                showDeleteConfirm = true
                            }
                        )
                    }
                }
                .padding(.horizontal, GranaTheme.Spacing.md)
                .padding(.bottom, GranaTheme.Spacing.md)
            }
        }
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
    }

    private var placeholderDetail: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(GranaTheme.Palette.teal.opacity(0.12))
                    .frame(width: 76, height: 76)
                Image(systemName: AppIcon.sidebarCreditCards.systemImage)
                    .font(.system(size: GranaTheme.IconSize.large))
                    .foregroundStyle(GranaTheme.Palette.tealDeep)
            }
            Text("Selecione um cartão")
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)
            Text("O detalhe da fatura aparece logo abaixo da faixa de cartões.")
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(GranaTheme.Spacing.xxxl)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
    }

    private var hasArchivedCard: Bool {
        store?.accounts.contains { $0.type == .creditCard && $0.archived } ?? false
    }

    private func cardsSubtitle(store: AccountStore, visibleCount: Int) -> String {
        let totalCount = store.accounts.filter { $0.type == .creditCard }.count
        if hasArchivedCard {
            return showArchived
                ? "\(visibleCount) de \(totalCount) cartões visíveis"
                : "\(visibleCount) cartões ativos"
        }
        return "\(visibleCount) \(visibleCount == 1 ? "cartão" : "cartões")"
    }

    private func reconcileSelection(visibleIds: [UUID]) {
        if let current = selectedCardId, visibleIds.contains(current) { return }
        selectedCardId = visibleIds.first
    }

    private var emptyState: some View {
        EmptyStateView(
            "Sem cartões por aqui",
            icon: .sidebarCreditCards,
            description: "Cadastre os cartões de crédito que você usa pra acompanhar as faturas, fechamento, vencimento e limite."
        ) {
            Button {
                formMode = .create
            } label: {
                Label("Cadastrar primeiro cartão", systemImage: AppIcon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(formMode != nil)
        }
    }

    private func visible(store: AccountStore) -> [Account] {
        store.accounts.filter { account in
            guard account.type == .creditCard else { return false }
            return showArchived ? true : !account.archived
        }
    }

    private func editingAccount(from mode: FormMode) -> Account? {
        if case let .edit(account) = mode { return account }
        return nil
    }
}

private struct CreditCardSelectorCard: View {
    let account: Account
    let institution: Institution?
    let details: CreditCardDetails?
    let currentBalance: Decimal
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggleArchive: () -> Void
    let onRequestDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                HStack(alignment: .center, spacing: GranaTheme.Spacing.sm) {
                    if let institution {
                        InstitutionIcon(kind: institution.kind, size: 40)
                    } else {
                        placeholderIcon
                    }

                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                        Text(bankName)
                            .font(GranaTheme.Typography.bodyEmphasis)
                            .foregroundStyle(titleColor)
                            .lineLimit(1)
                        Text(maskedNumber)
                            .font(GranaTheme.Typography.code)
                            .foregroundStyle(subtitleColor)
                    }

                    Spacer(minLength: GranaTheme.Spacing.none)

                    if account.archived {
                        Text("Arquivado")
                            .font(GranaTheme.Typography.caption2Emphasis)
                            .foregroundStyle(subtitleColor)
                            .padding(.horizontal, GranaTheme.Spacing.xs)
                            .padding(.vertical, GranaTheme.Spacing.xxs)
                            .background(badgeBackground, in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text("Fatura atual")
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(subtitleColor)
                    Text(currentBalance.magnitude.formatted(.currency(code: account.currency)))
                        .font(GranaTheme.Typography.moneyHeadline)
                        .foregroundStyle(titleColor)
                }

                if let limit = details?.creditLimit, limit > 0 {
                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                        CreditCardUsageBar(
                            percent: usagePercent(limit: limit),
                            tint: barTint
                        )
                        HStack {
                            Text("Limite \(limit.formatted(.currency(code: account.currency)))")
                                .font(GranaTheme.Typography.caption1)
                                .foregroundStyle(subtitleColor)
                            Spacer(minLength: GranaTheme.Spacing.none)
                            Text("\(Int(usagePercent(limit: limit) * 100))%")
                                .font(GranaTheme.Typography.caption1Emphasis)
                                .foregroundStyle(titleColor)
                        }
                    }
                }
            }
            .padding(GranaTheme.Spacing.md)
            .frame(width: 280, alignment: .leading)
            .background(backgroundShape)
            .overlay {
                RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
            }
            .shadow(color: shadowColor, radius: isSelected ? 18 : 8, y: isSelected ? 10 : 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Editar", action: onEdit)
            Button(account.archived ? "Desarquivar" : "Arquivar", action: onToggleArchive)
            Divider()
            Button("Apagar", role: .destructive, action: onRequestDelete)
        }
    }

    private var bankName: String {
        institution?.name ?? "Cartão"
    }

    private var maskedNumber: String {
        guard let last4 = details?.cardLastFour, last4.count == 4 else { return "••••" }
        return "•••• \(last4)"
    }

    private var titleColor: Color {
        isSelected ? GranaTheme.Palette.creamText : GranaTheme.Palette.ink
    }

    private var subtitleColor: Color {
        isSelected ? GranaTheme.Palette.creamText.opacity(0.78) : GranaTheme.Palette.muted
    }

    private var badgeBackground: Color {
        isSelected ? Color.white.opacity(0.14) : GranaTheme.Palette.soft
    }

    private var barTint: Color {
        isSelected ? Color.white.opacity(0.92) : GranaTheme.Palette.teal
    }

    private var borderColor: Color {
        isSelected ? GranaTheme.Palette.teal.opacity(0.34) : GranaTheme.Palette.line
    }

    private var shadowColor: Color {
        isSelected ? GranaTheme.Shadow.accentColor : GranaTheme.Shadow.rowColor
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
                .fill(GranaTheme.brandGradient())
        } else {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
                .fill(GranaTheme.Palette.paperSolid.opacity(0.96))
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
            .fill(isSelected ? Color.white.opacity(0.14) : GranaTheme.Palette.soft)
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: AppIcon.sidebarCreditCards.systemImage)
                    .font(.system(size: GranaTheme.IconSize.small))
                    .foregroundStyle(subtitleColor)
            }
    }

    private func usagePercent(limit: Decimal) -> Double {
        let limitValue = NSDecimalNumber(decimal: limit).doubleValue
        guard limitValue > 0 else { return 0 }
        let debtValue = NSDecimalNumber(decimal: currentBalance.magnitude).doubleValue
        return max(0, min(1, debtValue / limitValue))
    }
}

private struct CreditCardUsageBar: View {
    let percent: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.16))
                Capsule()
                    .fill(tint)
                    .frame(width: max(12, geometry.size.width * percent))
            }
        }
        .frame(height: 8)
    }
}
