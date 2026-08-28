import ComposableArchitecture
import Foundation
import SwiftUI

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
        VStack(spacing: GranaTheme.Spacing.none) {
            if store.isLoading, store.rows.isEmpty {
                ProgressView()
                    .padding(.vertical, GranaTheme.Spacing.lg)
            } else if store.rows.isEmpty {
                emptyView
            } else {
                table
            }
        }
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
        .task(id: store.statementId) {
            await store.send(.task).finish()
        }
    }

    private var emptyView: some View {
        VStack(spacing: GranaTheme.Spacing.xs) {
            Image(systemName: "tray")
                .font(.system(size: GranaTheme.IconSize.medium))
                .foregroundStyle(GranaTheme.Palette.muted)
            Text("Sem lançamentos nesta fatura")
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)
        }
        .padding(.vertical, GranaTheme.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }

    private var table: some View {
        GranaTable(sortedRows, sortOrder: $sortOrder) {
            TableColumn("Data", value: \.occurredAt) { row in
                Text(Self.dayMonthFormatter.string(from: row.occurredAt))
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
            .width(min: 92, ideal: 108, max: 124)

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
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(
                        row.subcategoryName == nil
                            ? GranaTheme.Palette.muted
                            : GranaTheme.Palette.ink
                    )
                    .lineLimit(1)
            }
            .width(min: 148, ideal: 180, max: 220)

            TableColumn("Descrição", value: \.description) { row in
                Text(row.description)
                    .font(GranaTheme.Typography.subheadlineEmphasis)
                    .foregroundStyle(GranaTheme.Palette.ink)
                    .lineLimit(1)
            }
            .width(min: 220, ideal: 360)

            TableColumn("Valor", value: \.signedAmount) { row in
                Text(row.signedAmount.formatted(.currency(code: currency)))
                    .font(GranaTheme.Typography.moneySubheadline)
                    .foregroundStyle(
                        row.signedAmount < 0
                            ? GranaTheme.Palette.ink
                            : GranaTheme.Palette.green
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
            .fill(GranaTheme.Palette.soft)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "questionmark")
                    .font(.system(size: GranaTheme.IconSize.small))
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
    }

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd 'de' MMM"
        f.locale = Locale(identifier: "pt_BR")
        return f
    }()
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
                    .font(.system(size: GranaTheme.IconSize.categoryGlyph(in: size)))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(icon.color.gradient)
            }
    }
}
