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
        ImportWizardStageScaffold(
            eyebrow: "Importação CSV",
            title: "Revise a fatura consolidada antes de importar",
            subtitle: "O arquivo já foi convertido em uma prévia da fatura. Escolha a conta-cartão, trate estornos e confirme a seleção final.",
            icon: .sidebarCreditCards,
            badges: heroBadges
        ) {
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
        } sidebar: {
            VStack(spacing: GranaTheme.Spacing.md) {
                ImportWizardSidebarCard(
                    title: "Resumo da fatura",
                    subtitle: resolution?.sourceFilename
                ) {
                    ImportWizardMetricRow(
                        label: "Conta-cartão",
                        value: resolution?.accountId == nil ? "Pendente" : "Definida"
                    )
                    ImportWizardMetricRow(label: "Compras válidas", value: "\(resolution?.rows.count ?? 0)")
                    ImportWizardMetricRow(label: "Selecionadas", value: "\(totalSelected)")
                    if duplicateCount > 0 {
                        ImportWizardMetricRow(label: "Duplicadas", value: "\(duplicateCount)")
                    }
                    if let negativeCount = resolution?.negativeRows.count, negativeCount > 0 {
                        ImportWizardMetricRow(label: "Negativos", value: "\(negativeCount)")
                    }
                }

                if let negatives = resolution?.negativeRows, !negatives.isEmpty {
                    negativeRowsSection(rows: negatives)
                }

                if resolution?.accountId == nil {
                    ImportWizardSidebarCard(
                        title: "Ação pendente",
                        subtitle: "CSV de fatura sempre precisa de uma conta-cartão explícita."
                    ) {
                        Text(
                            "Selecione a conta de destino para habilitar a confirmação. O fluxo não cria conta nova a partir do CSV."
                        )
                        .font(GranaTheme.Typography.callout)
                        .foregroundStyle(GranaTheme.Palette.muted)
                    }
                }
            }
        }
        .navigationSubtitle(resolution?.sourceFilename ?? "")
    }

    private var heroBadges: [ImportWizardBadge] {
        var badges: [ImportWizardBadge] = [
            .init(label: "CSV de fatura", tint: .teal),
            .init(label: "\(totalSelected) selecionadas", tint: .green),
        ]
        if duplicateCount > 0 {
            badges.append(.init(label: "\(duplicateCount) duplicadas", tint: .warning))
        }
        return badges
    }

    private var selectionCaption: String? {
        guard let resolution else { return nil }
        return resolution.accountId == nil ? "Escolha a conta-cartão de destino" : nil
    }

    private func negativeRowsSection(rows: [CSVNegativePreviewRow]) -> some View {
        let count = rows.count
        return ImportWizardSidebarCard(
            title: "Negativos para revisão",
            subtitle: "\(count) \(count == 1 ? "linha exige ajuste" : "linhas exigem ajuste")"
        ) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                Text(
                    "Pagamentos são ignorados. Estornos selecionados aqui serão vinculados à compra original antes do commit."
                )
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)

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
            subtitle: "Selecione a conta-cartão que receberá as compras desta fatura.",
            trailing: AnyView(
                Group {
                    if resolution?.accountId == nil {
                        ImportWizardBadgeView(badge: .init(label: "Escolha", tint: .warning))
                    } else {
                        ImportWizardBadgeView(badge: .init(label: "Definida", tint: .green))
                    }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                if let resolution {
                    if let accountName = selectedAccountName(for: resolution.accountId) {
                        ImportWizardInfoRow(label: "Conta atual") {
                            Text(accountName)
                        }
                    }

                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                        Text("Conta-cartão")
                            .font(GranaTheme.Typography.caption1)
                            .foregroundStyle(GranaTheme.Palette.muted)

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
                    }
                }
            }
            .padding(GranaTheme.Spacing.md)
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
            subtitle: "Revise a seleção final que seguirá para a classificação.",
            trailing: AnyView(ImportWizardBadgeView(badge: .init(
                label: "\(resolution.selectedCount)/\(resolution.rows.count)",
                tint: .neutral
            )))
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
