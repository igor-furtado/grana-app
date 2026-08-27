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

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            if store.isLoading, store.rows.isEmpty {
                ProgressView()
                    .padding(.vertical, GranaTheme.Spacing.lg)
            } else if store.rows.isEmpty {
                emptyView
            } else {
                rows
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

    private var rows: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            ForEach(Array(store.rows.enumerated()), id: \.element.id) { idx, row in
                if idx > 0 { Divider() }
                rowView(for: row)
            }
        }
    }

    private func rowView(for row: StatementTransactionRow) -> some View {
        return HStack(spacing: GranaTheme.Spacing.sm) {
            Text(Self.dayMonthFormatter.string(from: row.transaction.occurredAt))
                .font(GranaTheme.Typography.footnote)
                .foregroundStyle(GranaTheme.Palette.muted)
                .frame(width: 56, alignment: .leading)

            if let icon = row.category?.icon {
                CategoryIconBubble(icon: icon, size: 28)
            } else {
                placeholderIcon
            }

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                Text(row.transaction.description)
                    .font(GranaTheme.Typography.callout)
                    .lineLimit(1)
                if let category = row.category {
                    Text(category.name)
                        .font(GranaTheme.Typography.caption2)
                        .foregroundStyle(GranaTheme.Palette.muted)
                }
            }

            Spacer()

            Text("-\(row.transaction.amount.magnitude.formatted(.currency(code: "BRL")))")
                .font(GranaTheme.Typography.moneySubheadline)
                .foregroundStyle(GranaTheme.Palette.ink)
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .padding(.vertical, GranaTheme.Spacing.sm)
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
