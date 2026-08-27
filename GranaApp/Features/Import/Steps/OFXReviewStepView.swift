import ComposableArchitecture
import SwiftUI

struct OFXReviewStepView: View {
    @Bindable var store: StoreOf<OFXImportFeature>
    let onClose: () -> Void
    let onConfirm: () -> Void

    private var totalSelected: Int {
        store.state.totalSelected
    }

    private var allAccountsSelected: Bool {
        store.state.allAccountsSelected
    }

    var body: some View {
        ImportWizardStageScaffold {
            VStack(spacing: GranaTheme.Spacing.md) {
                accountAssignmentsPanel
                OFXTransactionsListCard(
                    resolutions: Binding(
                        get: { store.state.resolutions },
                        set: { store.send(.resolutionsUpdated($0)) }
                    ),
                    showsBankInHeader: store.state.resolutions.count > 1,
                    bankKind: { accountId in store.state.bankKind(for: accountId) }
                )
                .frame(maxHeight: .infinity)

                BottomActionBar(caption: selectionCaption) {
                    Button("Fechar") { onClose() }
                        .buttonStyle(GranaSecondaryButtonStyle())

                    Button("Avançar com \(totalSelected) \(totalSelected == 1 ? "transação" : "transações")") {
                        onConfirm()
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())
                    .disabled(totalSelected == 0 || !allAccountsSelected)
                }
            }
        }
    }

    private var accountAssignmentsPanel: some View {
        ImportWizardSectionCard(title: "Mapeamento das contas") {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                ForEach(store.state.resolutions.indices, id: \.self) { idx in
                    OFXAccountInfoCard(store: store, statementIndex: idx)
                }
            }
            .padding(GranaTheme.Spacing.md)
        }
    }

    private var selectionCaption: String? {
        allAccountsSelected ? nil : "Escolha a conta de destino de cada extrato"
    }
}

private struct OFXAccountInfoCard: View {
    @Bindable var store: StoreOf<OFXImportFeature>
    let statementIndex: Int

    private var resolution: OFXStatementResolution? {
        store.state.resolutions.indices.contains(statementIndex) ? store.state.resolutions[statementIndex] : nil
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
                                store.send(.accountSelected(statementIndex: statementIndex, accountId: newValue))
                            }
                        )
                    ) {
                        Text("Selecione…").tag(UUID?.none)
                        ForEach(store.state.availableAccounts) { account in
                            Text(store.state.label(for: account)).tag(UUID?.some(account.id))
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
        ImportWizardSectionCard(title: "Transações detectadas") {
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
            Text(resolution.ofxBankLabel)
                .font(GranaTheme.Typography.caption1Emphasis)
                .foregroundStyle(GranaTheme.Palette.tealDeep)
            Spacer()
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .padding(.vertical, GranaTheme.Spacing.xs)
        .background(GranaTheme.Palette.teal.opacity(0.08))
    }

    private func toggleAll(to value: Bool) {
        for resolutionIndex in resolutions.indices {
            for rowIndex in resolutions[resolutionIndex].rows.indices {
                resolutions[resolutionIndex].rows[rowIndex].selected = value
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
