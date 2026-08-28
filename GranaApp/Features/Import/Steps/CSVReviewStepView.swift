import ComposableArchitecture
import SwiftUI

struct CSVReviewStepView: View {
    @Bindable var store: StoreOf<CSVImportFeature>
    let onClose: () -> Void
    let onConfirm: () -> Void

    private var canConfirm: Bool {
        store.state.resolution.selectedCount > 0 && store.state.resolution.accountId != nil
    }

    var body: some View {
        ImportWizardStageScaffold {
            ImportWizardSplitLayout(currentStage: .triage) {
                VStack(spacing: GranaTheme.Spacing.md) {
                    CSVTransactionsListCard(
                        resolution: Binding(
                            get: { store.state.resolution },
                            set: { store.send(.resolutionUpdated($0)) }
                        ),
                        refundPurchases: { store.state.eligibleRefundPurchases(for: $0) },
                        institutionKind: store.state.bankKind(for: store.state.resolution.accountId),
                        onRefundPurchaseSelected: { rowId, purchaseId in
                            store.send(.refundPurchaseSelected(rowId: rowId, purchaseId: purchaseId))
                        },
                        onRefundSelectionChanged: { rowId, isSelected in
                            store.send(.refundSelectionChanged(rowId: rowId, isSelected: isSelected))
                        }
                    )
                    .frame(maxHeight: .infinity)

                    CSVAccountInfoCard(store: store)
                }
            } sidebarActions: {
                Button("Fechar") { onClose() }
                    .buttonStyle(GranaSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)

                Button("Avançar") { onConfirm() }
                    .buttonStyle(GranaPrimaryButtonStyle())
                    .disabled(!canConfirm)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct CSVAccountInfoCard: View {
    @Bindable var store: StoreOf<CSVImportFeature>

    var body: some View {
        ImportWizardSectionCard(
            title: "Conta de destino",
            trailing: AnyView(
                Picker(
                    "Conta-cartão",
                    selection: Binding(
                        get: { store.state.resolution.accountId },
                        set: { store.send(.accountSelected($0)) }
                    )
                ) {
                    Text("Selecione…").tag(UUID?.none)
                    ForEach(store.state.creditCardAccounts) { account in
                        Text(store.state.accountLabel(for: account)).tag(UUID?.some(account.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            )
        ) {}
    }
}

private struct CSVTransactionsListCard: View {
    @Binding var resolution: CSVStatementResolution
    let refundPurchases: (CSVNegativePreviewRow) -> [Transaction]
    let institutionKind: InstitutionKind?
    let onRefundPurchaseSelected: (UUID, UUID?) -> Void
    let onRefundSelectionChanged: (UUID, Bool) -> Void

    private enum Item: Identifiable {
        case purchase(Int)
        case negative(Int)

        var id: String {
            switch self {
            case let .purchase(index):
                "purchase-\(index)"
            case let .negative(index):
                "negative-\(index)"
            }
        }
    }

    private var orderedItems: [Item] {
        var items = resolution.rows.indices.map(Item.purchase)
        items.append(contentsOf: resolution.negativeRows.indices.map(Item.negative))

        return items.sorted { lhs, rhs in
            let leftDate = occurredAt(for: lhs)
            let rightDate = occurredAt(for: rhs)
            if leftDate == rightDate {
                return lhs.id < rhs.id
            }
            return leftDate < rightDate
        }
    }

    private var eligibleSelectionCount: Int {
        resolution.rows.filter { !$0.isDuplicate }.count
            + resolution.negativeRows.filter { $0.raw.kind == .refund && $0.purchaseId != nil }.count
    }

    private var allSelected: Bool {
        guard eligibleSelectionCount > 0 else { return false }
        let purchasesSelected = resolution.rows.filter { !$0.isDuplicate && $0.selected }.count
        let refundsSelected = resolution.negativeRows.filter {
            $0.raw.kind == .refund && $0.purchaseId != nil && $0.selected
        }.count
        return purchasesSelected + refundsSelected == eligibleSelectionCount
    }

    var body: some View {
        ImportWizardSectionCard(title: "Transações") {
            VStack(spacing: GranaTheme.Spacing.none) {
                TransactionsSelectionRow(
                    summary: selectionSummary,
                    allSelected: allSelected,
                    onToggleAll: toggleAll(to:)
                )
                Divider()

                ScrollView {
                    LazyVStack(spacing: GranaTheme.Spacing.none) {
                        ForEach(orderedItems) { item in
                            row(for: item)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func row(for item: Item) -> some View {
        switch item {
        case let .purchase(index):
            CSVPurchaseRowView(
                row: $resolution.rows[index],
                institutionKind: institutionKind
            )
            .padding(.horizontal, GranaTheme.Spacing.md)
            .padding(.vertical, GranaTheme.Spacing.sm)

        case let .negative(index):
            CSVNegativeRowView(
                row: resolution.negativeRows[index],
                selection: Binding(
                    get: { resolution.negativeRows[index].selected },
                    set: { onRefundSelectionChanged(resolution.negativeRows[index].id, $0) }
                ),
                refundPurchases: refundPurchases(resolution.negativeRows[index]),
                institutionKind: institutionKind,
                onPurchaseSelected: { purchaseId in
                    onRefundPurchaseSelected(resolution.negativeRows[index].id, purchaseId)
                }
            )
            .padding(.horizontal, GranaTheme.Spacing.md)
            .padding(.vertical, GranaTheme.Spacing.sm)
        }
    }

    private func occurredAt(for item: Item) -> Date {
        switch item {
        case let .purchase(index):
            resolution.rows[index].raw.date
        case let .negative(index):
            resolution.negativeRows[index].raw.date
        }
    }

    private func toggleAll(to value: Bool) {
        for index in resolution.rows.indices where !resolution.rows[index].isDuplicate {
            resolution.rows[index].selected = value
        }

        for index in resolution.negativeRows.indices
            where resolution.negativeRows[index].raw.kind == .refund && resolution.negativeRows[index].purchaseId != nil {
            onRefundSelectionChanged(resolution.negativeRows[index].id, value)
        }
    }

    private var selectionSummary: String {
        "\(resolution.selectedCount) de \(eligibleSelectionCount) selecionadas"
    }
}

private struct CSVPurchaseRowView: View {
    @Binding var row: CSVPreviewRow
    let institutionKind: InstitutionKind?

    var body: some View {
        TransactionRow(
            selection: row.isDuplicate ? nil : $row.selected,
            institutionKind: institutionKind,
            description: row.raw.description,
            memo: memo,
            date: row.raw.date,
            amount: row.raw.amount,
            amountKind: .outgoing,
            status: row.isDuplicate ? .duplicate : nil
        )
    }

    private var memo: String? {
        let tipo = row.raw.tipo
        guard !tipo.isEmpty, tipo != "Compra à vista" else { return nil }
        return tipo
    }
}

private struct CSVNegativeRowView: View {
    let row: CSVNegativePreviewRow
    let selection: Binding<Bool>
    let refundPurchases: [Transaction]
    let institutionKind: InstitutionKind?
    let onPurchaseSelected: (UUID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
            TransactionRow(
                selection: allowsSelection ? selection : nil,
                institutionKind: institutionKind,
                description: row.raw.description,
                memo: rowMemo,
                date: row.raw.date,
                amount: abs(row.raw.amount),
                amountKind: .outgoing,
                status: status
            )

            if row.raw.kind == .refund {
                Picker(
                    "Compra original",
                    selection: Binding(
                        get: { row.purchaseId },
                        set: onPurchaseSelected
                    )
                ) {
                    Text("Escolher compra").tag(UUID?.none)
                    ForEach(refundPurchases, id: \.id) { purchase in
                        Text("\(purchase.description) · \(purchase.amount.formatted(.currency(code: "BRL")))").tag(
                            UUID?.some(purchase.id)
                        )
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var allowsSelection: Bool {
        row.raw.kind == .refund && row.purchaseId != nil
    }

    private var rowMemo: String? {
        switch row.raw.kind {
        case .payment:
            "Pagamento"
        case .refund:
            row.purchaseId == nil ? "Escolha a compra original" : "Reembolso"
        }
    }

    private var status: TransactionRow.Status {
        switch row.raw.kind {
        case .payment:
            .init(label: "Pagamento ignorado", tint: .neutral)
        case .refund:
            if row.purchaseId == nil {
                .init(label: "Reembolso", tint: .info)
            } else if row.selected {
                .init(label: "Reembolso", tint: .info)
            } else {
                .init(label: "Desmarcada", tint: .neutral)
            }
        }
    }
}
