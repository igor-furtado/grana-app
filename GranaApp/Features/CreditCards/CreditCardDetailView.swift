import Charts
import ComposableArchitecture
import Foundation
import SwiftUI

/// Painel de detalhe do cartão selecionado.
/// A view só renderiza o read model do reducer; seleção de fatura e
/// carregamento de lançamentos ficam em `CreditCardStatementsFeature`.
struct CreditCardStatementsView: View {
    @Bindable var store: StoreOf<CreditCardStatementsFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                if let details = store.card.details, let limit = details.creditLimit, limit > 0 {
                    LimitGaugeBlock(
                        used: store.card.currentBalance.magnitude,
                        limit: limit,
                        currency: store.card.account.currency
                    )
                }
                if !store.statements.isEmpty || !store.projections.isEmpty {
                    StatementTimelineChart(
                        statements: store.statements,
                        projections: store.projections,
                        currency: store.card.account.currency,
                        selectedId: Binding(
                            get: { store.selectedStatementId },
                            set: { store.send(.statementSelected($0)) }
                        )
                    )
                    StatementCyclePanel(
                        statements: store.statements,
                        projections: store.projections,
                        selectedId: Binding(
                            get: { store.selectedStatementId },
                            set: { store.send(.statementSelected($0)) }
                        ),
                        currency: store.card.account.currency,
                        bestPurchaseDay: store.bestPurchaseDay,
                        onEditDates: { store.send(.editStatementDatesButtonTapped($0)) }
                    )
                }
                transactionsBlock
            }
            .padding(GranaTheme.Spacing.xl)
        }
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
        .sheet(
            item: $store.scope(\.$dateEditor, action: \.dateEditor)
        ) { dateEditorStore in
            StatementDateEditorView(store: dateEditorStore)
        }
        .task {
            await store.send(.task).finish()
        }
    }

    // MARK: - Transactions block

    private var transactionsBlock: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
            HStack {
                Text("Lançamentos")
                    .font(GranaTheme.Typography.headline)
                Spacer()
                if let total = store.selectedStatementTotal {
                    Text(total.formatted(.currency(code: store.card.account.currency)))
                        .font(GranaTheme.Typography.moneySubheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let statement = store.selectedStatement {
                statementSummary(statement)
                if let statementListStore = store.scope(state: \.statementList, action: \.statementList) {
                    StatementListView(store: statementListStore)
                }
            } else {
                // Fatura projetada (não persistida) ou nenhuma seleção:
                // não há transações pra listar.
                emptyTransactions
            }
        }
    }

    private func statementSummary(_ statement: Statement) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            summaryRow("Compras menos estornos", value: statement.netAmount)
            summaryRow("Pagamentos", value: statement.paymentApplied)
            summaryRow("Total a quitar", value: statement.totalAmount)
            if statement.remainingAmount > 0 {
                summaryRow("Diferença pendente", value: statement.remainingAmount)
            }
            if statement.paymentExcess > 0 {
                summaryRow("Pagamento excedente", value: statement.paymentExcess)
            }
            if statement.creditBalance > 0 {
                summaryRow("Saldo credor", value: statement.creditBalance)
            }
        }
        .padding(GranaTheme.Spacing.sm)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
    }

    private func summaryRow(_ label: String, value: Decimal) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: store.card.account.currency)))
                .font(GranaTheme.Typography.moneySubheadline)
                .gridColumnAlignment(.trailing)
        }
    }

    private var emptyTransactions: some View {
        HStack {
            Spacer()
            VStack(spacing: GranaTheme.Spacing.xs) {
                Image(systemName: "tray")
                    .font(.system(size: GranaTheme.IconSize.medium))
                    .foregroundStyle(.secondary)
                Text("Sem lançamentos nesta fatura")
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, GranaTheme.Spacing.xxl)
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
                .fill(GranaTheme.Palette.paperSolid.opacity(0.88))
        )
        .overlay {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
                .strokeBorder(GranaTheme.Palette.line, lineWidth: 1)
        }
    }
}

// MARK: - Limit gauge block

/// Bloco do tipo "Limite utilizado: R$ X de R$ Y" + barra horizontal.
/// Reaproveita as mesmas thresholds (30/70%) usadas no resto da feature
/// pra que verde/amarelo/vermelho tenham significado consistente.
private struct LimitGaugeBlock: View {
    let used: Decimal
    let limit: Decimal
    let currency: String

    private var percent: Double {
        let l = NSDecimalNumber(decimal: limit).doubleValue
        guard l > 0 else { return 0 }
        let u = NSDecimalNumber(decimal: used).doubleValue
        return max(0, min(1, u / l))
    }

    private var color: Color {
        if percent < 0.30 { return .success }
        if percent < 0.70 { return .warning }
        return .danger
    }

    private var available: Decimal {
        max(0, limit - used)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text("LIMITE UTILIZADO")
                        .font(GranaTheme.Typography.caption2Emphasis)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(used.formatted(.currency(code: currency)))
                        .font(GranaTheme.Typography.moneyTitle2)
                        .foregroundStyle(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: GranaTheme.Spacing.xxs) {
                    Text("LIMITE TOTAL")
                        .font(GranaTheme.Typography.caption2Emphasis)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(limit.formatted(.currency(code: currency)))
                        .font(GranaTheme.Typography.moneyHeadline)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * percent))
                }
            }
            .frame(height: 8)

            HStack(spacing: GranaTheme.Spacing.md) {
                HStack(spacing: GranaTheme.Spacing.xs) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text("Usado: \(used.formatted(.currency(code: currency)))")
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(.primary)
                }
                HStack(spacing: GranaTheme.Spacing.xs) {
                    Circle().fill(Color.secondary.opacity(0.4)).frame(width: 8, height: 8)
                    Text("Disponível: \(available.formatted(.currency(code: currency)))")
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(percent * 100))%")
                    .font(GranaTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(color)
            }
        }
        .padding(GranaTheme.Spacing.md)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
    }
}

// MARK: - Timeline chart

/// Barras de faturas no tempo. Cada barra é uma Statement (real ou
/// projetada). Clicar muda `selectedId`. Cores:
/// - Paga: cinza claro
/// - Aberta: cor de destaque (accent)
/// - Projetada (sem dados): cinza pontilhado simulado via opacidade reduzida
///
/// **Por que não usa `Chart` com series e legend:** as bandeiras semânticas
/// (paga/aberta/projetada) viram cor por barra, não uma legenda compartilhada
/// — fica mais limpo configurar `foregroundStyle` por item.
private struct StatementTimelineChart: View {
    let statements: [Statement]
    let projections: [StatementWindow]
    let currency: String
    @Binding var selectedId: UUID?

    private struct Bar: Identifiable, Hashable {
        let id: UUID
        let label: String
        let total: Decimal
        let status: Status
        let dueDate: Date

        enum Status: Hashable {
            case paid
            case open
            case projected
        }
    }

    private var bars: [Bar] {
        var result: [Bar] = statements.map { s in
            Bar(
                id: s.id,
                label: Self.monthFormatter.string(from: s.dueDate),
                total: s.totalAmount,
                status: {
                    switch s.status() {
                    case .forming, .closed: .open
                    case .paid, .settled: .paid
                    }
                }(),
                dueDate: s.dueDate
            )
        }
        for window in projections {
            result.append(Bar(
                id: UUID(),
                label: Self.monthFormatter.string(from: window.dueDate),
                total: 0,
                status: .projected,
                dueDate: window.dueDate
            ))
        }
        return result.sorted { $0.dueDate < $1.dueDate }
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
            Text("Faturas")
                .font(GranaTheme.Typography.headline)

            // Versão custom (HStack de retângulos) em vez de Swift Charts
            // BarMark porque precisamos de cor diferente por barra E hit
            // testing individual pra seleção — combinação onde o `Chart`
            // fica mais verbosa que vale a pena nesse caso.
            HStack(alignment: .bottom, spacing: GranaTheme.Spacing.md) {
                ForEach(bars) { bar in
                    BarColumn(
                        bar: bar,
                        maxTotal: maxBarValue,
                        isSelected: bar.id == selectedId,
                        currency: currency,
                        onTap: {
                            if bar.status != .projected {
                                selectedId = bar.id
                            }
                        }
                    )
                }
            }
            .frame(height: 140)
            .padding(.horizontal, GranaTheme.Spacing.xs)
            .padding(.vertical, GranaTheme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
        }
    }

    private var maxBarValue: Decimal {
        let max = bars.map(\.total).max() ?? 0
        return max > 0 ? max : 1
    }

    private struct BarColumn: View {
        let bar: Bar
        let maxTotal: Decimal
        let isSelected: Bool
        let currency: String
        let onTap: () -> Void

        var body: some View {
            VStack(spacing: GranaTheme.Spacing.xxs) {
                Text(bar.total > 0 ? bar.total.formatted(.currency(code: currency)) : " ")
                    .font(GranaTheme.Typography.moneyCaption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                GeometryReader { geo in
                    let fillHeight = fillHeight(in: geo.size.height)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(barColor)
                            .frame(width: 18, height: max(8, fillHeight))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }

                Text(bar.label.capitalized)
                    .font(isSelected ? GranaTheme.Typography.caption2Emphasis : GranaTheme.Typography.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }

        private var barColor: Color {
            switch bar.status {
            case .open:
                return isSelected ? Color.accentColor : Color.accentColor.opacity(0.5)
            case .paid:
                return isSelected ? Color.secondary : Color.secondary.opacity(0.45)
            case .projected:
                return Color.secondary.opacity(0.25)
            }
        }

        /// Altura proporcional ao maior valor dentro do bloco. Faturas
        /// projetadas (total = 0) ganham um stub mínimo (8pt) pra ficarem
        /// visíveis e clicáveis mesmo zeradas — caso contrário sumiriam.
        private func fillHeight(in available: CGFloat) -> CGFloat {
            let total = NSDecimalNumber(decimal: bar.total).doubleValue
            let max = NSDecimalNumber(decimal: maxTotal).doubleValue
            guard max > 0 else { return 8 }
            let ratio = total / max
            return CGFloat(ratio) * available
        }
    }
}

// MARK: - Cycle panel (3 columns)

/// Trio de cards "anterior / atual / próxima" centrado na fatura selecionada.
/// Caixa central com borda colorida — espelha o destaque do Inter pra fatura
/// em aberto. Quando a seleção está numa borda (primeira ou última fatura),
/// o card daquele lado fica vazio em vez de mostrar fatura aleatória.
private struct StatementCyclePanel: View {
    let statements: [Statement]
    let projections: [StatementWindow]
    @Binding var selectedId: UUID?
    let currency: String
    /// Dia "ideal" pra fazer uma compra (fechamento + 1) — só faz sentido
    /// pra fatura em aberto.
    let bestPurchaseDay: Int?
    let onEditDates: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
            cell(for: previousItem, role: .previous)
            cell(for: selectedItem, role: .selected)
            cell(for: nextItem, role: .next)
        }
    }

    // MARK: - Item resolution

    private enum CycleItem {
        case statement(Statement)
        case projection(StatementWindow)
        case none

        var closingDate: Date? {
            switch self {
            case let .statement(s): return s.closingDate
            case let .projection(w): return w.closingDate
            case .none: return nil
            }
        }

        var dueDate: Date? {
            switch self {
            case let .statement(s): return s.dueDate
            case let .projection(w): return w.dueDate
            case .none: return nil
            }
        }
    }

    /// Lista unificada (statements + projeções) ordenada por closingDate.
    /// `selectedId` só aponta pra Statement real — projeções não são
    /// selecionáveis.
    private var ordered: [CycleItem] {
        var items: [CycleItem] = statements.map { .statement($0) }
        items.append(contentsOf: projections.map { .projection($0) })
        return items.sorted { a, b -> Bool in
            (a.dueDate ?? .distantPast) < (b.dueDate ?? .distantPast)
        }
    }

    private var selectedIndex: Int? {
        guard let selectedId else { return nil }
        return ordered.firstIndex { item in
            if case let .statement(s) = item, s.id == selectedId { return true }
            return false
        }
    }

    private var selectedItem: CycleItem {
        guard let idx = selectedIndex else { return .none }
        return ordered[idx]
    }

    private var previousItem: CycleItem {
        guard let idx = selectedIndex, idx > 0 else { return .none }
        return ordered[idx - 1]
    }

    private var nextItem: CycleItem {
        guard let idx = selectedIndex, idx + 1 < ordered.count else { return .none }
        return ordered[idx + 1]
    }

    // MARK: - Cell rendering

    private enum Role {
        case previous, selected, next
    }

    @ViewBuilder
    private func cell(for item: CycleItem, role: Role) -> some View {
        switch item {
        case let .statement(s):
            StatementCycleCard(
                title: monthTitle(s.dueDate),
                amount: s.totalAmount,
                statusLabel: s.status().displayName,
                statusTint: s.status() == .forming ? .info : .neutral,
                closingDate: s.closingDate,
                dueDate: s.dueDate,
                bestPurchaseDay: role == .selected && s.status() == .forming
                    ? bestPurchaseDay
                    : nil,
                currency: currency,
                isHighlighted: role == .selected,
                isMuted: role != .selected,
                onTap: role == .selected ? nil : { selectedId = s.id },
                onEditDates: role == .selected ? { onEditDates(s.id) } : nil
            )
        case let .projection(w):
            StatementCycleCard(
                title: monthTitle(w.dueDate),
                amount: 0,
                statusLabel: "Prevista",
                statusTint: .neutral,
                closingDate: w.closingDate,
                dueDate: w.dueDate,
                bestPurchaseDay: nil,
                currency: currency,
                isHighlighted: false,
                isMuted: true,
                onTap: nil,
                onEditDates: nil
            )
        case .none:
            // Slot vazio com mesma largura pra manter o trio alinhado.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(minHeight: 120)
        }
    }

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private func monthTitle(_ date: Date) -> String {
        Self.monthYearFormatter.string(from: date).capitalized
    }
}

/// Card individual do trio de ciclo. Visual segue o padrão do Inter:
/// header com mês + badge de status, total grande, data de vencimento e —
/// quando é a fatura em aberto — o "melhor dia de compra".
private struct StatementCycleCard: View {
    let title: String
    let amount: Decimal
    let statusLabel: String
    let statusTint: BadgeTint
    let closingDate: Date
    let dueDate: Date
    let bestPurchaseDay: Int?
    let currency: String
    let isHighlighted: Bool
    let isMuted: Bool
    let onTap: (() -> Void)?
    let onEditDates: (() -> Void)?

    enum BadgeTint {
        case info, neutral
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            HStack(spacing: GranaTheme.Spacing.xs) {
                Text(title)
                    .font(GranaTheme.Typography.calloutEmphasis)
                StatusBadge(label: statusLabel, tint: statusTint)
                Spacer()
                if let onEditDates {
                    Button(action: onEditDates) {
                        Image(systemName: AppIcon.edit.systemImage)
                            .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(GranaTheme.Palette.paper.opacity(0.95))
                    )
                    .overlay {
                        Circle().strokeBorder(GranaTheme.Palette.line, lineWidth: 1)
                    }
                    .help("Editar datas da fatura")
                    .accessibilityLabel("Editar datas da fatura")
                }
            }

            Text(amount.formatted(.currency(code: currency)))
                .font(GranaTheme.Typography.moneyTitle3)

            Divider()

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                HStack {
                    Text("Data de fechamento")
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Self.dayMonthFormatter.string(from: closingDate))
                        .font(GranaTheme.Typography.footnoteEmphasis)
                }
                HStack {
                    Text("Data de vencimento")
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Self.dayMonthFormatter.string(from: dueDate))
                        .font(GranaTheme.Typography.footnoteEmphasis)
                }
                if let bestPurchaseDay {
                    HStack {
                        Text("Melhor dia de compra")
                            .font(GranaTheme.Typography.caption1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(bestPurchaseDay)")
                            .font(GranaTheme.Typography.footnoteEmphasis)
                    }
                }
            }
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
                .fill(GranaTheme.Palette.paperSolid.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
                .strokeBorder(
                    isHighlighted ? GranaTheme.Palette.teal : GranaTheme.Palette.line,
                    lineWidth: isHighlighted ? 1.5 : 1
                )
        )
        .opacity(isMuted ? 0.75 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private struct StatusBadge: View {
        let label: String
        let tint: BadgeTint

        var body: some View {
            Text(label)
                .font(GranaTheme.Typography.caption2Emphasis)
                .padding(.horizontal, GranaTheme.Spacing.xs)
                .padding(.vertical, GranaTheme.Spacing.xxs)
                .background(
                    Capsule().fill(background)
                )
                .foregroundStyle(foreground)
        }

        private var background: Color {
            switch tint {
            case .info: return Color.accentColor.opacity(0.18)
            case .neutral: return Color.secondary.opacity(0.18)
            }
        }

        private var foreground: Color {
            switch tint {
            case .info: return Color.accentColor
            case .neutral: return Color.secondary
            }
        }
    }
}

private struct StatementDateEditorView: View {
    @Bindable var store: StoreOf<StatementDateEditorFeature>

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            Form {
                Section {
                    DatePicker(
                        "Data de fechamento",
                        selection: $store.closingDate,
                        displayedComponents: .date
                    )
                    .disabled(store.isSaving)

                    DatePicker(
                        "Data de vencimento",
                        selection: $store.dueDate,
                        displayedComponents: .date
                    )
                    .disabled(store.isSaving)
                } header: {
                    Text(store.title)
                } footer: {
                    Text(
                        "Alterar o fechamento realoca compras e estornos entre faturas. Pagamentos permanecem na fatura onde foram registrados."
                    )
                }

                if let message = store.validationMessage ?? store.saveError {
                    Section {
                        Label {
                            Text(message)
                                .foregroundStyle(.danger)
                        } icon: {
                            Image(systemName: AppIcon.invalidDate.systemImage)
                                .foregroundStyle(.danger)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            BottomActionBar {
                Button("Cancelar") {
                    store.send(.cancelButtonTapped)
                }
                .disabled(store.isSaving)

                Button {
                    store.send(.saveButtonTapped)
                } label: {
                    if store.isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Salvar datas")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canSave || store.isSaving)
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 460, idealWidth: 460, maxWidth: 460, minHeight: 300)
        .environment(\.timeZone, TimeZone(secondsFromGMT: 0) ?? .current)
    }
}
