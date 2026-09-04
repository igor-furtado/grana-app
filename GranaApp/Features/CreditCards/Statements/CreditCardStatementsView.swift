import AppUI
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
        Group {
            if store.isLoading {
                CreditCardStatementsSkeletonView()
            } else {
                content
            }
        }
        .sheet(
            item: $store.scope(\.$dateEditor, action: \.dateEditor)
        ) { dateEditorStore in
            StatementDateEditorView(store: dateEditorStore)
        }
        .task {
            await store.send(.task).finish()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.lg) {
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
            .padding(AppUI.Theme.Spacing.xl)
        }
        .granaSurface(.subtle, cornerRadius: AppUI.Theme.Radius.hero)
    }

    private var transactionsBlock: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            Text("Lançamentos")
                .font(AppUI.Theme.Typography.headline)

            if store.selectedStatement != nil {
                if let statementListStore = store.scope(state: \.statementList, action: \.statementList) {
                    StatementListView(
                        store: statementListStore,
                        currency: store.card.account.currency
                    )
                }
            } else {
                emptyTransactions
            }
        }
    }

    private var emptyTransactions: some View {
        HStack {
            Spacer()
            VStack(spacing: AppUI.Theme.Spacing.xs) {
                Image(systemName: "tray")
                    .font(.system(size: AppUI.Theme.IconSize.medium))
                    .foregroundStyle(.secondary)
                Text("Sem lançamentos nesta fatura")
                    .font(AppUI.Theme.Typography.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, AppUI.Theme.Spacing.xxl)
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: AppUI.Theme.Radius.card, style: .continuous)
                .fill(AppUI.Theme.Palette.paperSolid.opacity(0.88))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppUI.Theme.Radius.card, style: .continuous)
                .strokeBorder(AppUI.Theme.Palette.line, lineWidth: 1)
        }
    }
}

private struct StatementTimelineChart: View {
    let statements: [Statement]
    let projections: [StatementWindow]
    let currency: String
    var calendar = Calendar.autoupdatingCurrent
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
                label: GranaDateFormat.shortMonth(s.dueDate),
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
                label: GranaDateFormat.shortMonth(window.dueDate),
                total: 0,
                status: .projected,
                dueDate: window.dueDate
            ))
        }
        return result.sorted { $0.dueDate < $1.dueDate }
    }

    private var visibleBars: [Bar] {
        StatementTimelineVisibleWindow(
            selectedDate: bars.first { $0.id == selectedId }?.dueDate,
            calendar: calendar
        ).items(from: bars, date: \.dueDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            Text("Faturas")
                .font(AppUI.Theme.Typography.headline)

            HStack(alignment: .bottom, spacing: AppUI.Theme.Spacing.md) {
                ForEach(visibleBars) { bar in
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
            .padding(.horizontal, AppUI.Theme.Spacing.xs)
            .padding(.vertical, AppUI.Theme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
        }
    }

    private var maxBarValue: Decimal {
        let max = visibleBars.map(\.total).max() ?? 0
        return max > 0 ? max : 1
    }

    private struct BarColumn: View {
        let bar: Bar
        let maxTotal: Decimal
        let isSelected: Bool
        let currency: String
        let onTap: () -> Void

        var body: some View {
            VStack(spacing: AppUI.Theme.Spacing.xxs) {
                Text(bar.total > 0 ? bar.total.formatted(.currency(code: currency)) : " ")
                    .font(AppUI.Theme.Typography.moneyCaption2)
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

                Text(bar.label)
                    .font(isSelected ? AppUI.Theme.Typography.caption2Emphasis : AppUI.Theme.Typography.caption2)
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

        private func fillHeight(in available: CGFloat) -> CGFloat {
            let total = NSDecimalNumber(decimal: bar.total).doubleValue
            let max = NSDecimalNumber(decimal: maxTotal).doubleValue
            guard max > 0 else { return 8 }
            let ratio = total / max
            return CGFloat(ratio) * available
        }
    }
}

struct StatementTimelineVisibleWindow {
    static let monthCount = 12

    var selectedDate: Date?
    var calendar: Calendar

    func items<Element>(from allItems: [Element], date: KeyPath<Element, Date>) -> [Element] {
        let sortedItems = allItems.sorted { $0[keyPath: date] < $1[keyPath: date] }
        guard sortedItems.count > Self.monthCount else {
            return sortedItems
        }

        guard
            let selectedDate,
            let selectedIndex = sortedItems.firstIndex(where: {
                calendar.isDate($0[keyPath: date], equalTo: selectedDate, toGranularity: .month)
            })
        else {
            return Array(sortedItems.prefix(Self.monthCount))
        }

        let preferredPastCount = (Self.monthCount - 1) / 2
        let maxStartIndex = sortedItems.count - Self.monthCount
        let startIndex = min(max(selectedIndex - preferredPastCount, 0), maxStartIndex)
        let endIndex = startIndex + Self.monthCount
        return Array(sortedItems[startIndex ..< endIndex])
    }
}

private struct StatementCyclePanel: View {
    let statements: [Statement]
    let projections: [StatementWindow]
    @Binding var selectedId: UUID?
    let currency: String
    let bestPurchaseDay: Int?
    let onEditDates: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppUI.Theme.Spacing.sm) {
            cell(for: previousItem, role: .previous)
            cell(for: selectedItem, role: .selected)
            cell(for: nextItem, role: .next)
        }
    }

    private enum CycleItem {
        case statement(Statement)
        case projection(StatementWindow)
        case none

        var dueDate: Date? {
            switch self {
            case let .statement(s): return s.dueDate
            case let .projection(w): return w.dueDate
            case .none: return nil
            }
        }
    }

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
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(minHeight: 120)
        }
    }

    private func monthTitle(_ date: Date) -> String {
        GranaDateFormat.dateOnlyShortMonth(date)
    }
}

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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            HStack(spacing: AppUI.Theme.Spacing.xs) {
                Text(title)
                    .font(AppUI.Theme.Typography.calloutEmphasis)
                StatusBadge(label: statusLabel, tint: statusTint)
                Spacer()
                if let onEditDates {
                    Button(action: onEditDates) {
                        Image(systemName: AppUI.Icon.edit.systemImage)
                            .font(.system(size: AppUI.Theme.IconSize.small, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(AppUI.Theme.Palette.paper.opacity(0.95))
                    )
                    .overlay {
                        Circle().strokeBorder(AppUI.Theme.Palette.line, lineWidth: 1)
                    }
                    .help("Editar datas da fatura")
                    .accessibilityLabel("Editar datas da fatura")
                }
            }

            Text(amount.formatted(.currency(code: currency)))
                .font(AppUI.Theme.Typography.moneyTitle3)

            Divider()

            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                HStack {
                    Text("Data de fechamento")
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(GranaDateFormat.dateOnlyDayMonth(closingDate))
                        .font(AppUI.Theme.Typography.footnoteEmphasis)
                }
                HStack {
                    Text("Data de vencimento")
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(GranaDateFormat.dateOnlyDayMonth(dueDate))
                        .font(AppUI.Theme.Typography.footnoteEmphasis)
                }
                if let bestPurchaseDay {
                    HStack {
                        Text("Melhor dia de compra")
                            .font(AppUI.Theme.Typography.caption1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(bestPurchaseDay)")
                            .font(AppUI.Theme.Typography.footnoteEmphasis)
                    }
                }
            }
        }
        .padding(AppUI.Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .opacity(isMuted ? 0.75 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private struct StatusBadge: View {
        let label: String
        let tint: BadgeTint

        var body: some View {
            Text(label)
                .font(AppUI.Theme.Typography.caption2Emphasis)
                .padding(.horizontal, AppUI.Theme.Spacing.xs)
                .padding(.vertical, AppUI.Theme.Spacing.xxs)
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
