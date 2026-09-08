import AppUI
import ComposableArchitecture
import SwiftUI

struct ImportReviewView: View {
    enum Mode {
        case modal
        case wizard(
            onImport: @MainActor @Sendable () -> Void,
            onBack: @MainActor @Sendable () -> Void
        )
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var store: StoreOf<ImportReviewFeature>
    var mode: Mode = .modal

    var body: some View {
        switch mode {
        case .modal:
            VStack(spacing: AppUI.Theme.Spacing.none) {
                content
                BottomActionBar {
                    Button("Fechar") { dismiss() }
                    Button {
                        store.send(.confirmAll)
                        dismiss()
                    } label: {
                        Text("Confirmar tudo")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.suggestions.allSatisfy(\.isReviewed))
                }
            }
            .frame(minWidth: 700, minHeight: 600)
        case let .wizard(onImport, onBack):
            AppUI.Wizard.Shell {
                AppUI.Wizard.Layout(steps: ImportWizardStage.presentedSteps(currentStage: .review)) {
                    content
                } sidebarActions: {
                    Button("Voltar") { onBack() }
                        .buttonStyle(GranaSecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    Button("Confirmar tudo") {
                        store.send(.confirmAll)
                    }
                    .buttonStyle(GranaSecondaryButtonStyle())
                    .disabled(store.suggestions.allSatisfy(\.isReviewed))
                    .frame(maxWidth: .infinity)
                    Button("Importar") { onImport() }
                        .buttonStyle(GranaPrimaryButtonStyle())
                        .disabled(store.suggestions.isEmpty)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.suggestions.isEmpty {
            emptyState
        } else {
            AppUI.Table(tableRows) {
                TableColumn("Status") { row in
                    if row.needsAttention {
                        ImportWizardTableStatusBadge(
                            status: .init(label: "Não Classificado", tint: .warning)
                        )
                    } else {
                        Text("Classificada")
                            .font(AppUI.Theme.Typography.caption1Emphasis)
                            .foregroundStyle(AppUI.Theme.Palette.tealDeep)
                    }
                }
                .width(min: 132, ideal: 156, max: 180)

                TableColumn("Data") { row in
                    Text(GranaDateFormat.fullDate(row.occurredAt))
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                }
                .width(min: 128, ideal: 148, max: 172)

                TableColumn("Descrição") { row in
                    HStack(spacing: AppUI.Theme.Spacing.sm) {
                        if let kind = row.institutionKind {
                            InstitutionIcon(kind: kind, size: 22)
                        }

                        Text(row.description)
                            .font(AppUI.Theme.Typography.subheadlineEmphasis)
                            .foregroundStyle(AppUI.Theme.Palette.ink)
                            .lineLimit(1)
                            .help(row.description)
                    }
                }

                TableColumn("Categoria") { row in
                    categoryMenu(for: row)
                }
                .width(min: 170, ideal: 220, max: 260)

                TableColumn("Subcategoria") { row in
                    subcategoryMenu(for: row)
                }
                .width(min: 170, ideal: 220, max: 260)

                TableColumn("Valor") { row in
                    Text(row.amount.formatted(.currency(code: "BRL")))
                        .font(AppUI.Theme.Typography.moneySubheadline)
                        .foregroundStyle(amountColor(for: row.categoryId))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 140, ideal: 140, max: 160)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            "Tudo categorizado",
            icon: .success,
            description: "Sem sugestões pendentes pra revisar."
        )
    }

    private var tableRows: [ImportReviewTableRow] {
        ImportReviewOrdering.orderedIndices(from: store.suggestions).map { index in
            let suggestion = store.suggestions[index]
            return ImportReviewTableRow(
                id: suggestion.id,
                index: index,
                occurredAt: suggestion.transactionOccurredAt,
                description: suggestion.transactionDescription,
                amount: suggestion.transactionAmount,
                categoryId: suggestion.categoryId,
                subcategoryId: suggestion.subcategoryId,
                needsAttention: ImportReviewOrdering.needsAttention(suggestion),
                institutionKind: store.state.institutionKind(forAccountId: suggestion.transactionAccountId)
            )
        }
    }

    private func categoryMenu(for row: ImportReviewTableRow) -> some View {
        Menu {
            ForEach(store.rootCategories) { category in
                Button(category.name) {
                    store.send(
                        .applyCorrection(
                            index: row.index,
                            categoryId: category.id,
                            subcategoryId: nil
                        )
                    )
                }
            }
        } label: {
            tableMenuLabel(text: rootName(for: row))
        }
        .menuStyle(.borderlessButton)
        .help(rootName(for: row))
    }

    private func subcategoryMenu(for row: ImportReviewTableRow) -> some View {
        Menu {
            Button("Nenhuma") {
                store.send(
                    .applyCorrection(
                        index: row.index,
                        categoryId: row.categoryId,
                        subcategoryId: nil
                    )
                )
            }
            ForEach(store.state.subcategories(of: row.categoryId)) { subcategory in
                Button(subcategory.name) {
                    store.send(
                        .applyCorrection(
                            index: row.index,
                            categoryId: row.categoryId,
                            subcategoryId: subcategory.id
                        )
                    )
                }
            }
        } label: {
            tableMenuLabel(text: subName(for: row) ?? "—")
        }
        .menuStyle(.borderlessButton)
        .help(subName(for: row) ?? "Sem subcategoria")
    }

    private func rootName(for row: ImportReviewTableRow) -> String {
        store.state.category(for: row.categoryId)?.name ?? "Categoria"
    }

    private func subName(for row: ImportReviewTableRow) -> String? {
        guard let subcategoryId = row.subcategoryId else { return nil }
        return store.state.category(for: subcategoryId)?.name
    }

    private func amountColor(for categoryId: UUID) -> Color {
        guard let category = store.state.category(for: categoryId) else {
            return .primary
        }
        switch category.kind {
        case .income: return .income
        case .transfer: return .transfer
        case .expense: return .primary
        }
    }

    private func tableMenuLabel(text: String) -> some View {
        HStack(spacing: AppUI.Theme.Spacing.xxs) {
            Text(text)
                .font(AppUI.Theme.Typography.caption1)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: AppUI.Icon.sort.systemImage)
                .font(.system(size: AppUI.Theme.IconSize.micro))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.xs)
        .padding(.vertical, AppUI.Theme.Spacing.xxs)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

enum ImportReviewOrdering {
    static func orderedIndices(from suggestions: [CategorizationSuggestion]) -> [Int] {
        orderedSuggestions(from: suggestions).map(\.index)
    }

    static func needsAttention(_ suggestion: CategorizationSuggestion) -> Bool {
        suggestion.source == .fallback || suggestion.originalCategorySlug == "nao-classificado"
    }

    private static func orderedSuggestions(
        from suggestions: [CategorizationSuggestion]
    ) -> [(index: Int, suggestion: CategorizationSuggestion)] {
        let indexed: [(index: Int, suggestion: CategorizationSuggestion)] = suggestions.enumerated().map {
            (index: $0.offset, suggestion: $0.element)
        }
        return indexed.sorted { lhs, rhs in
            if needsAttention(lhs.suggestion) != needsAttention(rhs.suggestion) {
                return needsAttention(lhs.suggestion) && !needsAttention(rhs.suggestion)
            }
            if lhs.suggestion.transactionOccurredAt == rhs.suggestion.transactionOccurredAt {
                return lhs.index < rhs.index
            }
            return lhs.suggestion.transactionOccurredAt < rhs.suggestion.transactionOccurredAt
        }
    }
}

private struct ImportReviewTableRow: Identifiable {
    let id: UUID
    let index: Int
    let occurredAt: Date
    let description: String
    let amount: Decimal
    let categoryId: UUID
    let subcategoryId: UUID?
    let needsAttention: Bool
    let institutionKind: InstitutionKind?
}
