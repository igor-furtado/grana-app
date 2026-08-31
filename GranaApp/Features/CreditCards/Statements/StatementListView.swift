import ComposableArchitecture
import Foundation
import SwiftUI
import AppUI

/// Lista de lançamentos da fatura selecionada. Faz snapshot remoto explícito
/// quando o `statementId` muda, em linha com a direção online-only da fatia.
///
/// Mantém `[UUID: Category]` carregado uma vez (snapshot) pra resolver o
/// nome + ícone da categoria de cada row sem segundo round-trip.
struct StatementListView: View {
    @Bindable var store: StoreOf<StatementListFeature>
    let currency: String
    @State private var sortOrder = [
        KeyPathComparator(\StatementTransactionTableRow.occurredAt, order: .reverse),
    ]

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.none) {
            if store.isLoading, store.rows.isEmpty {
                ProgressView()
                    .padding(.vertical, AppUI.Theme.Spacing.lg)
            } else if store.rows.isEmpty {
                emptyView
            } else {
                table
            }
        }
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
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
            TableColumn("Data", value: \.occurredAt) { row in
                Text(GranaDateFormat.fullDate(row.occurredAt))
                    .font(AppUI.Theme.Typography.caption1)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }
            .width(min: 128, ideal: 148, max: 172)

            TableColumn("Categoria", value: \.categorySortLabel) { row in
                Group {
                    if let category = row.category {
                        CategoryBadge(
                            category: category,
                            icon: row.categoryIcon,
                            iconOnly: true
                        )
                    } else {
                        placeholderIcon
                    }
                }
                .accessibilityLabel(row.categoryName ?? "Sem categoria")
            }
            .width(min: 58, ideal: 64, max: 72)

            TableColumn("Subcategoria", value: \.subcategorySortLabel) { row in
                Text(row.subcategoryDisplayName)
                    .font(AppUI.Theme.Typography.caption1)
                    .foregroundStyle(
                        row.subcategoryName == nil
                            ? AppUI.Theme.Palette.muted
                            : AppUI.Theme.Palette.ink
                    )
                    .lineLimit(1)
            }
            .width(min: 148, ideal: 180, max: 220)

            TableColumn("Descrição", value: \.description) { row in
                Text(row.description)
                    .font(AppUI.Theme.Typography.subheadlineEmphasis)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
                    .lineLimit(1)
            }
            .width(min: 220, ideal: 360)

            TableColumn("Valor", value: \.signedAmount) { row in
                Text(row.signedAmount.formatted(.currency(code: currency)))
                    .font(AppUI.Theme.Typography.moneySubheadline)
                    .foregroundStyle(
                        row.signedAmount < 0
                            ? AppUI.Theme.Palette.ink
                            : AppUI.Theme.Palette.green
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 132, ideal: 148, max: 180)
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
}

struct StatementTransactionTableRow: Identifiable, Equatable {
    let source: StatementTransactionRow

    var id: UUID {
        source.id
    }

    var occurredAt: Date {
        source.transaction.occurredAt
    }

    var category: Category? {
        source.category
    }

    var categoryName: String? {
        source.category?.name
    }

    var categorySortLabel: String {
        categoryName ?? ""
    }

    var categoryIcon: CategoryIcon? {
        source.category?.icon
    }

    var subcategoryName: String? {
        source.subcategory?.name
    }

    var subcategoryDisplayName: String {
        subcategoryName ?? "—"
    }

    var subcategorySortLabel: String {
        subcategoryName ?? ""
    }

    var description: String {
        source.transaction.description
    }

    var signedAmount: Decimal {
        if source.category?.kind == .income {
            return source.transaction.amount.magnitude
        }
        return -source.transaction.amount.magnitude
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
