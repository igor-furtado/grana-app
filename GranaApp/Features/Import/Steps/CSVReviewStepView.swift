import SwiftUI

struct CSVReviewStepView: View {
    @Bindable var store: ImportStore
    let dismiss: DismissAction

    private var resolution: CSVStatementResolution? {
        store.csvResolution
    }

    private var creditCardAccounts: [Account] {
        store.accounts.filter { account in
            guard account.type == .creditCard,
                  !account.archived,
                  let institutionId = account.institutionId,
                  let institution = store.institutions.first(where: { $0.id == institutionId })
            else { return false }
            return institution.capabilities.supports(.interCreditCardCSV)
        }
    }

    private var totalSelected: Int {
        resolution?.selectedCount ?? 0
    }

    private var duplicateCount: Int {
        resolution?.duplicateCount ?? 0
    }

    private var canConfirm: Bool {
        guard let resolution else { return false }
        guard totalSelected > 0 else { return false }
        return resolution.accountId != nil
    }

    var body: some View {
        ImportWizardStageScaffold() {
            VStack(spacing: GranaTheme.Spacing.md) {
                CSVAccountInfoCard(
                    store: store,
                    accounts: creditCardAccounts
                )

                if let resolutionBinding = Binding($store.csvResolution) {
                    CSVTransactionsListCard(
                        resolution: resolutionBinding,
                        institutionKind: bankKind(for: resolutionBinding.wrappedValue.accountId)
                    )
                    .frame(maxHeight: .infinity)
                }

                 if let negatives = resolution?.negativeRows, !negatives.isEmpty {
                    negativeRowsSection(rows: negatives)
                }


                BottomActionBar(caption: selectionCaption) {
                    Button("Fechar") { dismiss() }
                        .buttonStyle(GranaSecondaryButtonStyle())

                    Button("Avançar com \(totalSelected) \(totalSelected == 1 ? "transação" : "transações")") {
                        Task { await store.confirmCSVImport() }
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())
                    .disabled(!canConfirm)
                }
            }
        }
    }

    private var selectionCaption: String? {
        guard let resolution else { return nil }
        return resolution.accountId == nil ? "Escolha a conta-cartão de destino" : nil
    }

    private func negativeRowsSection(rows: [CSVNegativePreviewRow]) -> some View {
        let count = rows.count
        return ImportWizardSectionCard(
            title: "Negativos para revisão",
        ) {
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
                            Picker("Compra original", selection: Binding(
                                get: { row.purchaseId },
                                set: { store.setCSVRefundPurchase(rowId: row.id, purchaseId: $0) }
                            )) {
                                Text("Não importar este estorno").tag(UUID?.none)
                                ForEach(store.eligibleCSVRefundPurchases(for: row)) { purchase in
                                    Text(
                                        "\(purchase.description) · \(purchase.amount.formatted(.currency(code: "BRL")))"
                                    )
                                    .tag(UUID?.some(purchase.id))
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

    private func bankKind(for accountId: UUID?) -> InstitutionKind? {
        guard let accountId,
              let account = store.accounts.first(where: { $0.id == accountId }),
              let institutionId = account.institutionId,
              let institution = store.institutions.first(where: { $0.id == institutionId })
        else { return nil }
        return institution.kind
    }
}

private struct CSVAccountInfoCard: View {
    @Bindable var store: ImportStore
    let accounts: [Account]

    private var resolution: CSVStatementResolution? {
        store.csvResolution
    }

    var body: some View {
        ImportWizardSectionCard(
            title: "Conta de destino",
            subtitle: "Selecione",
            trailing: AnyView(
                 Picker("Conta-cartão", selection: Binding(
                            get: { store.csvResolution?.accountId },
                            set: { newValue in
                                Task { await store.setCSVAccount(newValue) }
                            }
                        )) {
                            Text("Selecione…").tag(UUID?.none)
                            ForEach(accounts) { account in
                                Text(Account.displayName(
                                    for: account,
                                    institutions: store.institutions,
                                    bankAccounts: store.bankDetails,
                                    creditCards: store.creditCards
                                ))
                                .tag(UUID?.some(account.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
            )
        ) {
        }
    }

    private func selectedAccountName(for accountId: UUID?) -> String? {
        guard let accountId,
              let account = store.accounts.first(where: { $0.id == accountId })
        else { return nil }
        return Account.displayName(
            for: account,
            institutions: store.institutions,
            bankAccounts: store.bankDetails,
            creditCards: store.creditCards
        )
    }
}

private struct CSVTransactionsListCard: View {
    @Binding var resolution: CSVStatementResolution
    let institutionKind: InstitutionKind?

    private var allSelected: Bool {
        !resolution.rows.isEmpty && resolution.rows.allSatisfy(\.selected)
    }

    var body: some View {
        ImportWizardSectionCard(
            title: "Compras detectadas",
        ) {
            VStack(spacing: GranaTheme.Spacing.none) {
                TransactionsSelectionRow(
                    summary: selectionSummary,
                    allSelected: allSelected,
                    onToggleAll: { value in
                        for idx in resolution.rows.indices {
                            resolution.rows[idx].selected = value
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
