import Foundation
import SwiftUI

/// Lista de lançamentos da fatura selecionada. Faz snapshot remoto explícito
/// quando o `statementId` muda, em linha com a direção online-only da fatia.
///
/// Mantém `[UUID: Category]` carregado uma vez (snapshot) pra resolver o
/// nome + ícone da categoria de cada row sem segundo round-trip.
struct StatementTransactionsList: View {
    let statementId: UUID
    let container: AppContainer

    @State private var transactions: [Transaction] = []
    @State private var categoryById: [UUID: Category] = [:]
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            if isLoading, transactions.isEmpty {
                ProgressView()
                    .padding(.vertical, GranaTheme.Spacing.lg)
            } else if transactions.isEmpty {
                emptyView
            } else {
                rows
            }
        }
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
        .task(id: statementId) {
            await loadCategoriesOnce()
            await loadTransactions()
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
            ForEach(Array(transactions.enumerated()), id: \.element.id) { idx, transaction in
                if idx > 0 { Divider() }
                row(for: transaction)
            }
        }
    }

    private func row(for transaction: Transaction) -> some View {
        let category = categoryById[transaction.categoryId]
        return HStack(spacing: GranaTheme.Spacing.sm) {
            Text(Self.dayMonthFormatter.string(from: transaction.occurredAt))
                .font(GranaTheme.Typography.footnote)
                .foregroundStyle(GranaTheme.Palette.muted)
                .frame(width: 56, alignment: .leading)

            if let icon = category?.icon {
                CategoryIconBubble(icon: icon, size: 28)
            } else {
                placeholderIcon
            }

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                Text(transaction.description)
                    .font(GranaTheme.Typography.callout)
                    .lineLimit(1)
                if let category {
                    Text(category.name)
                        .font(GranaTheme.Typography.caption2)
                        .foregroundStyle(GranaTheme.Palette.muted)
                }
            }

            Spacer()

            Text("-\(transaction.amount.magnitude.formatted(.currency(code: "BRL")))")
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

    // MARK: - Loading

    private func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            transactions = try await container.remoteStatements.loadTransactions(statementId: statementId)
        } catch is CancellationError {
        } catch {
            NoticeCenter.shared.report(error)
        }
    }

    /// Carrega categorias uma vez (snapshot) — não precisam de stream porque
    /// raramente mudam durante a visualização. Mapa por id pro lookup O(1)
    /// no `row(for:)`.
    private func loadCategoriesOnce() async {
        guard categoryById.isEmpty else { return }
        do {
            let categories = try await container.categoryCatalog.load()
            categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        } catch {
            // Não bloqueante — sem categoria a row mostra só descrição.
            NoticeCenter.capture(error, title: "Falha ao carregar categorias")
        }
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
