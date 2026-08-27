import SwiftUI

struct OFXReviewStepView: View {
    @Bindable var store: ImportStore
    let dismiss: DismissAction

    private var totalRows: Int {
        store.ofxResolutions.reduce(0) { $0 + $1.rows.count }
    }

    private var totalSelected: Int {
        store.ofxResolutions.reduce(0) { $0 + $1.rows.filter(\.selected).count }
    }

    private var duplicateCount: Int {
        store.ofxResolutions.reduce(0) { $0 + $1.rows.filter(\.isDuplicate).count }
    }

    private var resolvedAccountsCount: Int {
        store.ofxResolutions.filter { $0.accountId != nil }.count
    }

    private var allAccountsSelected: Bool {
        store.ofxResolutions.allSatisfy { $0.accountId != nil }
    }

    var body: some View {
        ImportWizardStageScaffold() {
            VStack(spacing: GranaTheme.Spacing.md) {
                accountAssignmentsPanel
                OFXTransactionsListCard(
                    resolutions: $store.ofxResolutions,
                    showsBankInHeader: store.ofxResolutions.count > 1,
                    bankKind: { accountId in bankKind(for: accountId) }
                )
                .frame(maxHeight: .infinity)

                BottomActionBar(caption: selectionCaption) {
                    Button("Fechar") { dismiss() }
                        .buttonStyle(GranaSecondaryButtonStyle())

                    Button("Avançar com \(totalSelected) \(totalSelected == 1 ? "transação" : "transações")") {
                        Task { await store.confirmOFXImport() }
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())
                    .disabled(totalSelected == 0 || !allAccountsSelected)
                }
            }
        } 
    }

    private var accountAssignmentsPanel: some View {
        ImportWizardSectionCard(
            title: "Mapeamento das contas",
        ) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                ForEach(store.ofxResolutions.indices, id: \.self) { idx in
                    OFXAccountInfoCard(store: store, statementIndex: idx)
                }
            }
            .padding(GranaTheme.Spacing.md)
        }
    }

    private var heroSubtitle: String {
        if store.ofxResolutions.count == 1 {
            return "O arquivo já foi analisado. Agora confirme a conta de destino e revise a seleção das transações."
        }
        return "O arquivo contém \(store.ofxResolutions.count) extratos. Revise cada vínculo de conta e só então avance para a categorização."
    }

    private var selectionCaption: String? {
        allAccountsSelected ? nil : "Escolha a conta de destino de cada extrato"
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

private struct OFXAccountInfoCard: View {
    @Bindable var store: ImportStore
    let statementIndex: Int

    private var resolution: OFXStatementResolution? {
        store.ofxResolutions.indices.contains(statementIndex)
            ? store.ofxResolutions[statementIndex]
            : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            HStack(alignment: .center, spacing: GranaTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text("Extrato \(statementIndex + 1)")
                        .font(GranaTheme.Typography.headline)
                        .foregroundStyle(GranaTheme.Palette.ink)
                    Text("Banco e conta lidos do OFX")
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)
                }

                Spacer(minLength: GranaTheme.Spacing.none)

                if let resolution {
                    statusBadge(for: resolution)
                }
            }

            if let resolution {
                ImportWizardInfoRow(label: "Banco do extrato") {
                    Text(resolution.ofxBankLabel)
                }

                ImportWizardInfoRow(label: "Conta do extrato") {
                    Text(resolution.ofxAccountLabel)
                }

                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text("Conta de destino")
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)

                    Picker(
                        "Conta de destino",
                        selection: Binding(
                            get: { resolution.accountId },
                            set: { newValue in
                                Task { await store.setOFXAccount(statementIndex: statementIndex, to: newValue) }
                            }
                        )
                    ) {
                        Text("Selecione…").tag(UUID?.none)
                        ForEach(availableAccounts) { account in
                            Text(label(for: account)).tag(UUID?.some(account.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GranaTheme.Palette.paper.opacity(0.64),
            in: RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
        )
    }

    private var availableAccounts: [Account] {
        store.accounts
            .filter { account in
                guard !account.archived,
                      let institutionId = account.institutionId,
                      let institution = store.institutions.first(where: { $0.id == institutionId })
                else { return false }
                return institution.capabilities.supports(.ofx)
            }
            .sorted { label(for: $0).localizedCaseInsensitiveCompare(label(for: $1)) == .orderedAscending }
    }

    private func label(for account: Account) -> String {
        Account.displayName(
            for: account,
            institutions: store.institutions,
            bankAccounts: store.bankDetails,
            creditCards: store.creditCards
        )
    }

    @ViewBuilder
    private func statusBadge(for resolution: OFXStatementResolution) -> some View {
        if resolution.accountId == nil {
            ImportWizardBadgeView(badge: .init(label: "Escolha", tint: .warning))
        } else if resolution.wasAutoDetected {
            ImportWizardBadgeView(badge: .init(label: "Detectada", tint: .green))
        } else {
            ImportWizardBadgeView(badge: .init(label: "Confirmada", tint: .teal))
        }
    }
}

private struct OFXTransactionsListCard: View {
    @Binding var resolutions: [OFXStatementResolution]
    let showsBankInHeader: Bool
    let bankKind: (UUID?) -> InstitutionKind?

    private var totalRows: Int {
        resolutions.reduce(0) { $0 + $1.rows.count }
    }

    private var selectedCount: Int {
        resolutions.reduce(0) { $0 + $1.rows.filter(\.selected).count }
    }

    private var duplicateCount: Int {
        resolutions.reduce(0) { $0 + $1.rows.filter(\.isDuplicate).count }
    }

    private var allSelected: Bool {
        let rows = resolutions.flatMap(\.rows)
        return !rows.isEmpty && rows.allSatisfy(\.selected)
    }

    var body: some View {
        ImportWizardSectionCard(
            title: "Transações detectadas",
        ) {
            VStack(spacing: GranaTheme.Spacing.none) {
                TransactionsSelectionRow(
                    summary: selectionSummary,
                    allSelected: allSelected,
                    onToggleAll: toggleAll(to:)
                )
                Divider()

                ScrollView {
                    LazyVStack(spacing: GranaTheme.Spacing.none) {
                        ForEach($resolutions) { $resolution in
                            if showsBankInHeader {
                                bankSubheader(for: resolution)
                            }

                            let kind = bankKind(resolution.accountId)
                            ForEach($resolution.rows) { $row in
                                OFXRowView(row: $row, institutionKind: kind)
                                    .padding(.horizontal, GranaTheme.Spacing.md)
                                    .padding(.vertical, GranaTheme.Spacing.sm)
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func bankSubheader(for resolution: OFXStatementResolution) -> some View {
        HStack {
            Text(bankName(for: resolution))
                .font(GranaTheme.Typography.caption1Emphasis)
                .foregroundStyle(GranaTheme.Palette.tealDeep)
            Spacer()
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .padding(.vertical, GranaTheme.Spacing.xs)
        .background(GranaTheme.Palette.teal.opacity(0.08))
    }

    private func bankName(for resolution: OFXStatementResolution) -> String {
        resolution.ofxBankLabel
    }

    private func toggleAll(to value: Bool) {
        for resIdx in resolutions.indices {
            for rowIdx in resolutions[resIdx].rows.indices {
                resolutions[resIdx].rows[rowIdx].selected = value
            }
        }
    }

    private var selectionSummary: String {
        var parts = ["\(selectedCount) de \(totalRows) selecionadas"]
        if duplicateCount > 0 {
            parts.append("\(duplicateCount) \(duplicateCount == 1 ? "duplicada" : "duplicadas")")
        }
        return parts.joined(separator: " · ")
    }
}

private struct OFXRowView: View {
    @Binding var row: OFXPreviewRow
    let institutionKind: InstitutionKind?

    var body: some View {
        TransactionRow(
            selection: $row.selected,
            institutionKind: institutionKind,
            description: primaryDescription,
            memo: nil,
            date: row.derived.occurredAt,
            amount: row.derived.amount,
            amountKind: row.derived.amount < 0 ? .outgoing : .incoming,
            status: row.isDuplicate ? .duplicate : nil
        )
    }

    private var primaryDescription: String {
        if let name = row.raw.name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty
        {
            return name
        }
        return row.derived.description
    }
}
