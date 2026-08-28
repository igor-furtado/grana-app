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
                        institutionKind: store.state.bankKind(for: store.state.resolution.accountId),
                        onNegativeSelectionChanged: { rowId, isSelected in
                            store.send(.negativeSelectionChanged(rowId: rowId, isSelected: isSelected))
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
    let institutionKind: InstitutionKind?
    let onNegativeSelectionChanged: (UUID, Bool) -> Void

    private var tableRows: [CSVTransactionTableRow] {
        let purchaseRows = resolution.rows.map {
            CSVTransactionTableRow(
                id: "purchase-\($0.id.uuidString)",
                rowID: $0.id,
                date: $0.raw.date,
                description: $0.raw.description,
                memo: purchaseMemo(for: $0),
                amount: $0.raw.amount,
                status: $0.isDuplicate ? .duplicate : nil,
                kind: .purchase
            )
        }
        let negativeRows = resolution.negativeRows.map {
            CSVTransactionTableRow(
                id: "negative-\($0.id.uuidString)",
                rowID: $0.id,
                date: $0.raw.date,
                description: $0.raw.description,
                memo: negativeMemo(for: $0),
                amount: abs($0.raw.amount),
                status: negativeStatus(for: $0),
                kind: $0.raw.kind == .payment ? .payment : .balance
            )
        }

        return (purchaseRows + negativeRows).sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.id < rhs.id
            }
            return lhs.date < rhs.date
        }
    }

    private var eligibleSelectionCount: Int {
        resolution.rows.filter { !$0.isDuplicate }.count
            + resolution.negativeRows.filter { $0.raw.kind == .balance }.count
    }

    private var allSelected: Bool {
        guard eligibleSelectionCount > 0 else { return false }
        let purchasesSelected = resolution.rows.filter { !$0.isDuplicate && $0.selected }.count
        let balancesSelected = resolution.negativeRows.filter { $0.raw.kind == .balance && $0.selected }.count
        return purchasesSelected + balancesSelected == eligibleSelectionCount
    }

    var body: some View {
        ImportWizardSectionCard(title: "Transações") {
            GranaTable(tableRows) {
                TableColumn("") { row in
                    selectionCell(for: row)
                }
                .width(min: 38, ideal: 44, max: 48)

                TableColumn("Data") { row in
                    Text(row.date.formatted(date: .numeric, time: .omitted))
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)
                }
                .width(min: 92, ideal: 104, max: 118)

                TableColumn("Descrição") { row in
                    HStack(spacing: GranaTheme.Spacing.sm) {
                        if let institutionKind {
                            InstitutionIcon(kind: institutionKind, size: 22)
                        }

                        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                            Text(row.description)
                                .font(GranaTheme.Typography.subheadlineEmphasis)
                                .foregroundStyle(GranaTheme.Palette.ink)
                                .lineLimit(1)
                            if let memo = row.memo {
                                Text(memo)
                                    .font(GranaTheme.Typography.caption1)
                                    .foregroundStyle(GranaTheme.Palette.muted)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                TableColumn("Situação") { row in
                    statusCell(for: row)
                }
                .width(min: 180, ideal: 240, max: 320)

                TableColumn("Valor") { row in
                    Text(row.amount.formatted(.currency(code: "BRL")))
                        .font(GranaTheme.Typography.moneySubheadline)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 120, ideal: 140, max: 160)
            } filterBar: {
                TransactionsSelectionRow(
                    summary: selectionSummary,
                    allSelected: allSelected,
                    onToggleAll: toggleAll(to:)
                )
            }
        }
    }

    @ViewBuilder
    private func selectionCell(for row: CSVTransactionTableRow) -> some View {
        if let selection = selectionBinding(for: row) {
            Toggle("", isOn: selection)
                .toggleStyle(.checkbox)
                .labelsHidden()
        } else {
            Color.clear
                .frame(width: 16, height: 16)
        }
    }

    @ViewBuilder
    private func statusCell(for row: CSVTransactionTableRow) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
            if let status = row.status {
                ImportWizardTableStatusBadge(status: status)
            } else {
                Text("Importar")
                    .font(GranaTheme.Typography.caption1Emphasis)
                    .foregroundStyle(GranaTheme.Palette.tealDeep)
            }
        }
    }

    private func toggleAll(to value: Bool) {
        for index in resolution.rows.indices where !resolution.rows[index].isDuplicate {
            resolution.rows[index].selected = value
        }

        for index in resolution.negativeRows.indices
            where resolution.negativeRows[index].raw.kind == .balance {
            onNegativeSelectionChanged(resolution.negativeRows[index].id, value)
        }
    }

    private var selectionSummary: String {
        "\(resolution.selectedCount) de \(eligibleSelectionCount) selecionadas"
    }

    private func selectionBinding(for row: CSVTransactionTableRow) -> Binding<Bool>? {
        switch row.kind {
        case .purchase:
            guard let index = resolution.rows.firstIndex(where: { $0.id == row.rowID }),
                  !resolution.rows[index].isDuplicate else {
                return nil
            }
            return $resolution.rows[index].selected
        case .payment:
            return nil
        case .balance:
            guard let index = resolution.negativeRows.firstIndex(where: { $0.id == row.rowID }) else {
                return nil
            }
            return Binding(
                get: { resolution.negativeRows[index].selected },
                set: { onNegativeSelectionChanged(resolution.negativeRows[index].id, $0) }
            )
        }
    }

    private func purchaseMemo(for row: CSVPreviewRow) -> String? {
        let tipo = row.raw.tipo
        guard !tipo.isEmpty, tipo != "Compra à vista" else { return nil }
        return tipo
    }

    private func negativeMemo(for row: CSVNegativePreviewRow) -> String? {
        switch row.raw.kind {
        case .payment:
            "Pagamento"
        case .balance:
            "Saldo"
        }
    }

    private func negativeStatus(for row: CSVNegativePreviewRow) -> TransactionRow.Status {
        switch row.raw.kind {
        case .payment:
            .init(label: "Pagamento", tint: .neutral)
        case .balance:
            if row.selected {
                .init(label: "Saldo", tint: .info)
            } else {
                .init(label: "Saldo", tint: .neutral)
            }
        }
    }

    private func negativeRow(for row: CSVTransactionTableRow) -> CSVNegativePreviewRow? {
        resolution.negativeRows.first(where: { $0.id == row.rowID })
    }
}

private struct CSVTransactionTableRow: Identifiable {
    enum Kind {
        case purchase
        case payment
        case balance
    }

    let id: String
    let rowID: UUID
    let date: Date
    let description: String
    let memo: String?
    let amount: Decimal
    let status: TransactionRow.Status?
    let kind: Kind
}
