import AppUI
import ComposableArchitecture
import Foundation
import SwiftUI

/// Lista de lançamentos da fatura selecionada. Faz snapshot remoto explícito
/// quando o `statementId` muda, em linha com a direção online-only da fatia.
///
/// Mantém `[UUID: Category]` carregado uma vez (snapshot) pra resolver o
/// nome + ícone da categoria de cada row sem segundo round-trip.
struct StatementListView: View {
    private static let numberLocale = Locale(identifier: "pt_BR")

    @Bindable var store: StoreOf<StatementListFeature>
    let currency: String
    @State private var sortOrder = [
        KeyPathComparator(\StatementTransactionTableRow.occurredAt, order: .reverse),
    ]

    var body: some View {
        Group {
            if store.isLoading {
                StatementListSkeletonView()
            } else {
                VStack(spacing: AppUI.Theme.Spacing.none) {
                    if store.rows.isEmpty {
                        emptyView
                    } else {
                        table
                    }
                }
                .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
            }
        }
        .task(id: store.statementId) {
            await store.send(.task).finish()
        }
    }

    private var emptyView: some View {
        VStack(spacing: AppUI.Theme.Spacing.xs) {
            Image(systemName: "tray")
                .font(.system(size: AppUI.Theme.IconSize.medium))
                .foregroundStyle(AppUI.Theme.Palette.muted)
            Text("Sem lançamentos nesta fatura")
                .font(AppUI.Theme.Typography.callout)
                .foregroundStyle(AppUI.Theme.Palette.muted)
        }
        .padding(.vertical, AppUI.Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }

    private var table: some View {
        AppUI.Table(sortedRows, sortOrder: $sortOrder) {
            TableColumn("Tipo", value: \.purchaseDisplayName) { row in
                Text(row.purchaseDisplayName)
                    .font(AppUI.Theme.Typography.caption1)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
                    .lineLimit(1)
            }
            .width(min: 92, ideal: 116, max: 136)

            TableColumn("Data", value: \.occurredAt) { row in
                Text(GranaDateFormat.fullDate(row.occurredAt))
                    .font(AppUI.Theme.Typography.caption1)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }
            .width(min: 110, ideal: 140, max: 140)

            TableColumn("Categoria", value: \.categorySortLabel) { row in
                HStack(spacing: AppUI.Theme.Spacing.xs) {
                    if let category = row.category {
                        CategoryBadge(
                            category: category,
                            icon: row.categoryIcon,
                            iconOnly: true
                        )
                    } else {
                        placeholderIcon
                    }

                    Text(row.categoryDisplayName)
                        .font(AppUI.Theme.Typography.footnoteEmphasis)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                        .lineLimit(1)
                }
                .help(row.categoryName ?? "Sem categoria")
            }
            .width(min: 170, ideal: 220, max: 220)

            TableColumn("Descrição", value: \.description) { row in
                Text(row.description)
                    .font(AppUI.Theme.Typography.subheadlineEmphasis)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
                    .lineLimit(1)
            }

            TableColumn("Valor", value: \.amount) { row in
                accountingAmount(row.amount)
                    .foregroundStyle(amountColor(for: row))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 140, ideal: 140, max: 160)
        }
        .frame(minHeight: 260, idealHeight: min(CGFloat(sortedRows.count) * 44 + 44, 520), maxHeight: 520)
    }

    private var sortedRows: [StatementTransactionTableRow] {
        store.tableRows.sorted(using: sortOrder)
    }

    private var placeholderIcon: some View {
        Circle()
            .fill(AppUI.Theme.Palette.soft)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "questionmark")
                    .font(.system(size: AppUI.Theme.IconSize.small))
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }
    }

    private func accountingAmount(_ amount: Decimal) -> some View {
        let number = amount.formatted(
            .number
                .precision(.fractionLength(2))
                .locale(Self.numberLocale)
        )
        return HStack(spacing: AppUI.Theme.Spacing.xxs) {
            Text(currencySymbol)
                .foregroundStyle(AppUI.Theme.Palette.muted)
            Spacer(minLength: AppUI.Theme.Spacing.xxs)
            Text(number)
        }
        .font(AppUI.Theme.Typography.moneySubheadline)
    }

    private func amountColor(for row: StatementTransactionTableRow) -> Color {
        switch row.category?.kind {
        case .income:
            return .income
        case .transfer:
            return .transfer
        case .expense:
            return .expense
        case .none:
            return .primary
        }
    }

    private var currencySymbol: String {
        currency == "BRL" ? "R$" : currency
    }
}

struct StatementTransactionTableRow: Identifiable, Equatable {
    let source: StatementTransactionRow

    var id: UUID {
        source.id
    }

    var occurredAt: Date {
        source.transaction.occurredAt
    }

    var purchaseDisplayName: String {
        switch source.transaction.purchaseType {
        case .installment:
            if let installmentIndex = source.transaction.installmentIndex,
               let installmentCount = source.transaction.installmentCount
            {
                return "Parcela \(installmentIndex)/\(installmentCount)"
            }
            return "Parcelada"
        case .cash, .none:
            return "À vista"
        }
    }

    var category: Category? {
        source.category
    }

    var categoryName: String? {
        source.category?.name
    }

    var categorySortLabel: String {
        categoryDisplayName
    }

    var categoryIcon: CategoryIcon? {
        source.category?.icon
    }

    var subcategoryName: String? {
        source.subcategory?.name
    }

    var categoryDisplayName: String {
        subcategoryName ?? categoryName ?? "Sem categoria"
    }

    var description: String {
        source.transaction.description
    }

    var amount: Decimal {
        source.transaction.amount.magnitude
    }
}

/// Bolha redonda com o ícone da categoria + cor associada. Match visual
/// com o resto do app (sidebar de Categorias usa o mesmo padrão).
struct CategoryIconBubble: View {
    let icon: CategoryIcon
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(icon.color.opacity(0.18))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: icon.systemImage)
                    .font(.system(size: AppUI.Theme.IconSize.categoryGlyph(in: size)))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(icon.color.gradient)
            }
    }
}
