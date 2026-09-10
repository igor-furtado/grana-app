import AppUI
import ComposableArchitecture
import SwiftUI

struct ImportReviewView: View {
    enum Mode {
        case modal
        case wizard(onBack: @MainActor @Sendable () -> Void)
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
        case let .wizard(onBack):
            AppUI.Form.Shell {
                AppUI.Form.Header(
                    title: "Revisão",
                    subtitle: "Confira categorias e subcategorias antes da importação"
                ) {
                    ImportWizardInlineSteps(steps: ImportWizardStage.presentedSteps(currentStage: .review))
                }

                content
                    .padding(.horizontal, AppUI.Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                AppUI.Form.Actions {
                    Button("Voltar") { onBack() }
                        .buttonStyle(GranaSecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    Button("Confirmar tudo") {
                        store.send(.confirmAll)
                    }
                    .buttonStyle(GranaSecondaryButtonStyle())
                    .disabled(store.suggestions.allSatisfy(\.isReviewed))
                    .frame(maxWidth: .infinity)
                    Button("Importar") { store.send(.importButtonTapped) }
                        .buttonStyle(GranaPrimaryButtonStyle())
                        .disabled(!store.canImport)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.suggestions.isEmpty {
            emptyState
        } else {
            AppUI.Table(tableRows) {
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

                TableColumn("Detalhe") { row in
                    if row.isTransfer {
                        transferAccountMenu(for: row)
                    } else {
                        subcategoryMenu(for: row)
                    }
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
                transactionId: suggestion.transactionId,
                index: index,
                occurredAt: suggestion.transactionOccurredAt,
                description: suggestion.transactionDescription,
                amount: suggestion.transactionAmount,
                categoryId: suggestion.categoryId,
                subcategoryId: suggestion.subcategoryId,
                statementAccountId: suggestion.transactionAccountId,
                isTransfer: store.state.isTransfer(categoryId: suggestion.categoryId),
                isTransferIncomplete: store.state.invalidTransferTransactionIds.contains(suggestion.transactionId),
                transferAccountLabel: transferAccountLabel(for: suggestion),
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

    private func transferAccountMenu(for row: ImportReviewTableRow) -> some View {
        Menu {
            Button("Selecionar") {
                store.send(.transferAccountChanged(index: row.index, accountId: nil))
            }
            ForEach(transferAccountOptions(excluding: row.statementAccountId)) { account in
                Button(accountLabel(for: account)) {
                    store.send(.transferAccountChanged(index: row.index, accountId: account.id))
                }
            }
        } label: {
            tableMenuLabel(text: row.transferAccountLabel)
        }
        .menuStyle(.borderlessButton)
        .help(row.isTransferIncomplete ? "Escolha a \(transferAccountFieldName(for: row).lowercased())" : row
            .transferAccountLabel)
    }

    private func rootName(for row: ImportReviewTableRow) -> String {
        store.state.category(for: row.categoryId)?.name ?? "Categoria"
    }

    private func subName(for row: ImportReviewTableRow) -> String? {
        guard let subcategoryId = row.subcategoryId else { return nil }
        return store.state.category(for: subcategoryId)?.name
    }

    private func transferAccountLabel(for suggestion: CategorizationSuggestion) -> String {
        let fieldName = transferAccountFieldName(transactionId: suggestion.transactionId)
        if let accountId = store.state.transferAccountSelections[suggestion.transactionId] {
            if let account = store.accounts.first(where: { $0.id == accountId }) {
                return "\(fieldName): \(accountLabel(for: account))"
            }
        }
        return fieldName
    }

    private func transferAccountFieldName(for row: ImportReviewTableRow) -> String {
        transferAccountFieldName(transactionId: row.transactionId)
    }

    private func transferAccountFieldName(transactionId: UUID) -> String {
        store.state.transferCounterpartyRole(forTransactionId: transactionId)
    }

    private func transferAccountOptions(excluding accountId: UUID) -> [Account] {
        store.accounts.filter { $0.id != accountId && !$0.archived }
    }

    private func accountLabel(for account: Account) -> String {
        if let institutionId = account.institutionId {
            if let institution = store.institutions.first(where: { $0.id == institutionId }) {
                return "\(institution.name) · \(account.type.displayName)"
            }
        }
        return account.type.displayName
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

    private static func orderedSuggestions(
        from suggestions: [CategorizationSuggestion]
    ) -> [(index: Int, suggestion: CategorizationSuggestion)] {
        let indexed: [(index: Int, suggestion: CategorizationSuggestion)] = suggestions.enumerated().map {
            (index: $0.offset, suggestion: $0.element)
        }
        return indexed.sorted { lhs, rhs in
            if lhs.suggestion.transactionOccurredAt == rhs.suggestion.transactionOccurredAt {
                return lhs.index < rhs.index
            }
            return lhs.suggestion.transactionOccurredAt < rhs.suggestion.transactionOccurredAt
        }
    }
}

private struct ImportReviewTableRow: Identifiable {
    let id: UUID
    let transactionId: UUID
    let index: Int
    let occurredAt: Date
    let description: String
    let amount: Decimal
    let categoryId: UUID
    let subcategoryId: UUID?
    let statementAccountId: UUID
    let isTransfer: Bool
    let isTransferIncomplete: Bool
    let transferAccountLabel: String
    let institutionKind: InstitutionKind?
}
