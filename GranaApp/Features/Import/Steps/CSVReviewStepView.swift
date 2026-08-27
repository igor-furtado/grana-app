import ComposableArchitecture
import SwiftUI

struct CSVReviewStepView: View {
    @Bindable var store: StoreOf<CSVImportFeature>
    let onClose: () -> Void
    let onConfirm: () -> Void

    private var totalSelected: Int {
        store.state.resolution.selectedCount
    }

    private var canConfirm: Bool {
        totalSelected > 0 && store.state.resolution.accountId != nil
    }

    var body: some View {
        ImportWizardStageScaffold {
            VStack(spacing: GranaTheme.Spacing.md) {
                CSVAccountInfoCard(store: store)

                CSVTransactionsListCard(
                    resolution: Binding(
                        get: { store.state.resolution },
                        set: { store.send(.resolutionUpdated($0)) }
                    ),
                    institutionKind: store.state.bankKind(for: store.state.resolution.accountId)
                )
                .frame(maxHeight: .infinity)

                if !store.state.resolution.negativeRows.isEmpty {
                    negativeRowsSection(rows: store.state.resolution.negativeRows)
                }

                BottomActionBar(caption: selectionCaption) {
                    Button("Fechar") { onClose() }
                        .buttonStyle(GranaSecondaryButtonStyle())

                    Button("Avançar com \(totalSelected) \(totalSelected == 1 ? "transação" : "transações")") {
                        onConfirm()
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())
                    .disabled(!canConfirm)
                }
            }
        }
    }

    private var selectionCaption: String? {
        store.state.resolution.accountId == nil ? "Escolha a conta-cartão de destino" : nil
    }

    private func negativeRowsSection(rows: [CSVNegativePreviewRow]) -> some View {
        ImportWizardSectionCard(title: "Negativos para revisão") {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                        HStack(alignment: .center, spacing: GranaTheme.Spacing.sm) {
                            Text(row.raw.date, format: .dateTime.day().month().year())
                                .font(GranaTheme.Typography.caption1)
                                .foregroundStyle(GranaTheme.Palette.muted)
                                .frame(width: 90, alignment: .leading)

                            Text(row.raw.description)
                                .font(GranaTheme.Typography.calloutEmphasis)
                                .foregroundStyle(GranaTheme.Palette.ink)
                                .lineLimit(1)

                            Spacer(minLength: GranaTheme.Spacing.none)

                            Text(row.raw.amount, format: .currency(code: "BRL"))
                                .font(GranaTheme.Typography.moneyFootnote)
                                .foregroundStyle(GranaTheme.Palette.muted)
                        }

                        if row.raw.kind == .refund {
                            Picker(
                                "Compra original",
                                selection: Binding(
                                    get: { row.purchaseId },
                                    set: { store.send(.refundPurchaseSelected(rowId: row.id, purchaseId: $0)) }
                                )
                            ) {
                                Text("Não importar este estorno").tag(UUID?.none)
                                ForEach(store.state.eligibleRefundPurchases(for: row)) { purchase in
                                    Text("\(purchase.description) · \(purchase.amount.formatted(.currency(code: "BRL")))").tag(
                                        UUID?.some(purchase.id)
                                    )
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            Text("Pagamento ignorado; importe a transferência pelo extrato da conta.")
                                .font(GranaTheme.Typography.caption1)
                                .foregroundStyle(GranaTheme.Palette.muted)
                        }
                    }

                    if row.id != rows.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct CSVAccountInfoCard: View {
    @Bindable var store: StoreOf<CSVImportFeature>

    var body: some View {
        ImportWizardSectionCard(
            title: "Conta de destino",
            subtitle: "Selecione",
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

    private var allSelected: Bool {
        !resolution.rows.isEmpty && resolution.rows.allSatisfy(\.selected)
    }

    var body: some View {
        ImportWizardSectionCard(title: "Compras detectadas") {
            VStack(spacing: GranaTheme.Spacing.none) {
                TransactionsSelectionRow(
                    summary: selectionSummary,
                    allSelected: allSelected,
                    onToggleAll: { value in
                        for index in resolution.rows.indices {
                            resolution.rows[index].selected = value
                        }
                    }
                )
                Divider()

                ScrollView {
                    LazyVStack(spacing: GranaTheme.Spacing.none) {
                        ForEach($resolution.rows) { $row in
                            CSVRowView(row: $row, institutionKind: institutionKind)
                                .padding(.horizontal, GranaTheme.Spacing.md)
                                .padding(.vertical, GranaTheme.Spacing.sm)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var selectionSummary: String {
        let selected = resolution.selectedCount
        let total = resolution.rows.count
        var parts = ["\(selected) de \(total) selecionadas"]
        if resolution.duplicateCount > 0 {
            parts.append("\(resolution.duplicateCount) \(resolution.duplicateCount == 1 ? "duplicada" : "duplicadas")")
        }
        return parts.joined(separator: " · ")
    }
}

private struct CSVRowView: View {
    @Binding var row: CSVPreviewRow
    let institutionKind: InstitutionKind?

    var body: some View {
        TransactionRow(
            selection: $row.selected,
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
