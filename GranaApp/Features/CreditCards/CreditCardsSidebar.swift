import SwiftUI

/// Sidebar da tela de Cartões. Cabeçalho com totais agregados (dívida total,
/// limite total, % usado) + lista de linhas compactas — uma por cartão —
/// com mini-logo, last4, dívida atual e barra de uso. Ações contextuais
/// vivem no menu de contexto de cada linha enquanto o inspetor dedicado
/// ainda não existe.
///
/// **Por que não reusa `CreditCardListItem` (versão "cartão grande")**: a
/// linha aqui é compacta (~64pt de altura) e foca em densidade — o
/// destaque visual fica no card grande do detalhe.
struct CreditCardsSidebar: View {
    let store: AccountStore
    let cards: [Account]
    @Binding var selectedId: UUID?
    let onEdit: (Account) -> Void
    let onToggleArchive: (Account) -> Void
    let onRequestDelete: (Account) -> Void

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            if cards.count >= 2 {
                totalsHeader
                    .padding(.horizontal, GranaTheme.Spacing.md)
                    .padding(.top, GranaTheme.Spacing.sm)
                    .padding(.bottom, GranaTheme.Spacing.sm)
                Divider()
            }

            ScrollView {
                LazyVStack(spacing: GranaTheme.Spacing.none) {
                    ForEach(cards) { account in
                        SidebarCardRow(
                            account: account,
                            institution: store.institution(forAccount: account),
                            details: store.creditCard(for: account.id),
                            currentBalance: store.currentBalance(for: account),
                            isSelected: account.id == selectedId,
                            onEdit: { onEdit(account) },
                            onToggleArchive: { onToggleArchive(account) },
                            onRequestDelete: { onRequestDelete(account) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedId = account.id }
                    }
                }
                .padding(.vertical, GranaTheme.Spacing.xs)
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Totals header

    private var totalsHeader: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
            Text("TOTAIS")
                .font(GranaTheme.Typography.caption2Emphasis)
                .tracking(0.8)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text("Dívida")
                        .font(GranaTheme.Typography.caption2)
                        .foregroundStyle(.secondary)
                    Text(totalDebt.formatted(.currency(code: currency)))
                        .font(GranaTheme.Typography.moneySubheadline)
                        .foregroundStyle(totalDebt > 0 ? .danger : .primary)
                }
                Spacer()
                if totalLimit > 0 {
                    VStack(alignment: .trailing, spacing: GranaTheme.Spacing.xxs) {
                        Text("Limite")
                            .font(GranaTheme.Typography.caption2)
                            .foregroundStyle(.secondary)
                        Text(totalLimit.formatted(.currency(code: currency)))
                            .font(GranaTheme.Typography.moneySubheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }

            if let pct = usagePercent {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    SidebarUsageBar(percent: pct, color: usageColor(for: pct))
                    (Text("\(Int(pct * 100))%")
                        .font(GranaTheme.Typography.caption2Emphasis)
                        + Text(" usado")
                        .font(GranaTheme.Typography.caption2))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var totalDebt: Decimal {
        cards.reduce(Decimal(0)) { acc, card in
            acc + store.currentBalance(for: card).magnitude
        }
    }

    private var totalLimit: Decimal {
        cards
            .compactMap { store.creditCard(for: $0.id)?.creditLimit }
            .reduce(0, +)
    }

    private var usagePercent: Double? {
        let limit = NSDecimalNumber(decimal: totalLimit).doubleValue
        guard limit > 0 else { return nil }
        let debt = NSDecimalNumber(decimal: totalDebt).doubleValue
        return max(0, min(1, debt / limit))
    }

    private var currency: String {
        cards.first?.currency ?? "BRL"
    }

    private func usageColor(for pct: Double) -> Color {
        if pct < 0.30 { return .success }
        if pct < 0.70 { return .warning }
        return .danger
    }
}

// MARK: - Sidebar row

/// Linha compacta da sidebar: mini-logo + nome + last4 (linha 1), dívida
/// atual (linha 2), barra de uso quando há limite (linha 3). Quando o item
/// está selecionado, ganha background na cor de seleção do sistema.
private struct SidebarCardRow: View {
    let account: Account
    let institution: Institution?
    let details: CreditCardDetails?
    let currentBalance: Decimal
    let isSelected: Bool
    let onEdit: () -> Void
    let onToggleArchive: () -> Void
    let onRequestDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            if let institution {
                InstitutionIcon(kind: institution.kind, size: 28)
            } else {
                placeholderIcon
            }

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                HStack(spacing: GranaTheme.Spacing.xs) {
                    Text(bankName)
                        .font(GranaTheme.Typography.calloutEmphasis)
                        .lineLimit(1)
                    if account.archived {
                        Text("arquivado")
                            .font(GranaTheme.Typography.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)

                HStack(spacing: GranaTheme.Spacing.xs) {
                    Text(maskedNumber)
                        .font(GranaTheme.Typography.code)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : .secondary)
                    Spacer()
                    Text(debtMagnitude.formatted(.currency(code: account.currency)))
                        .font(GranaTheme.Typography.moneyFootnote)
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : (debtMagnitude > 0 ? .danger : .secondary)
                        )
                }

                if let pct = limitPercent {
                    SidebarUsageBar(
                        percent: pct,
                        color: isSelected ? Color.white.opacity(0.9) : barColor(for: pct),
                        trackColor: isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.20)
                    )
                    .padding(.top, GranaTheme.Spacing.xxs)
                }
            }
        }
        .padding(.horizontal, GranaTheme.Spacing.sm)
        .padding(.vertical, GranaTheme.Spacing.xs)
        .background(rowBackground)
        .opacity(account.archived ? 0.65 : 1)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
        .contextMenu {
            Button("Editar", action: onEdit)
            Button(account.archived ? "Desarquivar" : "Arquivar", action: onToggleArchive)
            Divider()
            Button("Apagar", role: .destructive, action: onRequestDelete)
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor)
                .padding(.horizontal, 6)
        } else if isHovered {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .padding(.horizontal, 6)
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: GranaTheme.IconSize.small))
                    .foregroundStyle(.secondary)
            }
    }

    private var bankName: String {
        institution?.name ?? "Cartão"
    }

    private var maskedNumber: String {
        guard let last4 = details?.cardLastFour, last4.count == 4 else { return "" }
        return "•••• \(last4)"
    }

    private var debtMagnitude: Decimal {
        currentBalance.magnitude
    }

    private var limitPercent: Double? {
        guard let limit = details?.creditLimit, limit > 0 else { return nil }
        let l = NSDecimalNumber(decimal: limit).doubleValue
        let d = NSDecimalNumber(decimal: debtMagnitude).doubleValue
        return max(0, min(1, d / l))
    }

    private func barColor(for pct: Double) -> Color {
        if pct < 0.30 { return .success }
        if pct < 0.70 { return .warning }
        return .danger
    }
}

// MARK: - Mini usage bar

/// Barra fininha (3pt) usada na sidebar. Separada da `UsageBar` "principal"
/// porque ali a barra é 6pt e tem outras necessidades visuais — aqui a
/// densidade extrema da linha pede o mínimo possível.
private struct SidebarUsageBar: View {
    let percent: Double
    let color: Color
    var trackColor: Color = Color.secondary.opacity(0.20)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule().fill(color)
                    .frame(width: max(2, geo.size.width * percent))
            }
        }
        .frame(height: 3)
    }
}
