import ComposableArchitecture
import SwiftUI
import AppUI

struct OFXReviewStepView: View {
    @Bindable var store: StoreOf<OFXImportFeature>
    @State private var selectedStatementID: OFXStatementResolution.ID?
    let onClose: () -> Void
    let onConfirm: () -> Void

    private var totalSelected: Int {
        store.state.totalSelected
    }

    private var allAccountsSelected: Bool {
        store.state.allAccountsSelected
    }

    private var selectedStatementIndex: Int {
        if let selectedStatementID,
           let index = store.state.resolutions.firstIndex(where: { $0.id == selectedStatementID }) {
            return index
        }
        return 0
    }

    var body: some View {
        AppUI.Wizard.Shell {
            AppUI.Wizard.Layout(steps: ImportWizardStage.presentedSteps(currentStage: .triage)) {
                VStack(spacing: AppUI.Theme.Spacing.md) {
                    OFXTransactionsListCard(
                        resolutions: Binding(
                            get: { store.state.resolutions },
                            set: { store.send(.resolutionsUpdated($0)) }
                        ),
                        selectedStatementID: $selectedStatementID,
                        bankKind: { accountId in store.state.bankKind(for: accountId) }
                    )
                    .frame(maxHeight: .infinity)

                    if store.state.resolutions.indices.contains(selectedStatementIndex) {
                        OFXAccountInfoCard(store: store, statementIndex: selectedStatementIndex)
                    }
                }
            } sidebarActions: {
                Button("Fechar") { onClose() }
                    .buttonStyle(GranaSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)

                Button("Avançar") { onConfirm() }
                    .buttonStyle(GranaPrimaryButtonStyle())
                    .disabled(totalSelected == 0 || !allAccountsSelected)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if selectedStatementID == nil {
                selectedStatementID = store.state.resolutions.first?.id
            }
        }
        .onChange(of: store.state.resolutions.map(\.id)) { _, ids in
            if let selectedStatementID, ids.contains(selectedStatementID) {
                return
            }
            selectedStatementID = ids.first
        }
    }
}

private struct OFXAccountInfoCard: View {
    @Bindable var store: StoreOf<OFXImportFeature>
    let statementIndex: Int

    private var resolution: OFXStatementResolution? {
        store.state.resolutions.indices.contains(statementIndex) ? store.state.resolutions[statementIndex] : nil
    }

    var body: some View {
        ImportWizardSectionCard(
            title: "Conta de destino",
            trailing: AnyView(
                AppUI.Selector(
                    placeholder: "Selecione…",
                    options: store.state.availableAccounts.map {
                        .init(id: $0.id, title: store.state.label(for: $0))
                    },
                    selection: Binding(
                        get: { resolution?.accountId },
                        set: { newValue in
                            store.send(.accountSelected(statementIndex: statementIndex, accountId: newValue))
                        }
                    ),
                    icon: "building.columns"
                )
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            )
        ) {
            if let resolution {
                HStack(spacing: AppUI.Theme.Spacing.md) {
                    ImportWizardInfoRow(label: "Banco") {
                        Text(resolution.ofxBankLabel)
                    }

                    ImportWizardInfoRow(label: "Conta do extrato") {
                        Text(resolution.ofxAccountLabel)
                    }
                }
                .padding(.horizontal, AppUI.Theme.Spacing.md)
                .padding(.bottom, AppUI.Theme.Spacing.md)
            }
        }
    }
}

private struct ImportWizardInfoRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
            Text(label)
                .font(AppUI.Theme.Typography.caption1)
                .foregroundStyle(AppUI.Theme.Palette.muted)
            content()
                .font(AppUI.Theme.Typography.callout)
                .foregroundStyle(AppUI.Theme.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


private struct OFXTransactionsListCard: View {
    @Binding var resolutions: [OFXStatementResolution]
    @Binding var selectedStatementID: OFXStatementResolution.ID?
    let bankKind: (UUID?) -> InstitutionKind?

    private var selectedIndex: Int {
        if let selectedStatementID,
           let index = resolutions.firstIndex(where: { $0.id == selectedStatementID }) {
            return index
        }
        return 0
    }

    private var currentResolution: OFXStatementResolution? {
        resolutions.indices.contains(selectedIndex) ? resolutions[selectedIndex] : nil
    }

    private var tableRows: [OFXTransactionTableRow] {
        guard let currentResolution else { return [] }
        return currentResolution.rows.map {
            OFXTransactionTableRow(
                id: $0.id,
                date: $0.derived.occurredAt,
                description: $0.derived.description,
                amount: $0.derived.amount.magnitude,
                amountKind: $0.derived.amount < 0 ? .outgoing : .incoming,
                status: $0.isDuplicate ? .duplicate : nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.date < rhs.date
        }
    }

    private var currentSelectedCount: Int {
        guard let currentResolution else { return 0 }
        return currentResolution.rows.filter(\.selected).count
    }

    private var currentEligibleCount: Int {
        guard let currentResolution else { return 0 }
        return currentResolution.rows.filter { !$0.isDuplicate }.count
    }

    private var allSelected: Bool {
        guard let currentResolution, currentEligibleCount > 0 else { return false }
        return currentResolution.rows.filter { !$0.isDuplicate && $0.selected }.count == currentEligibleCount
    }

    var body: some View {
        ImportWizardSectionCard(title: "Transações") {
            AppUI.Table(tableRows) {
                TableColumn("") { row in
                    if let selection = selectionBinding(for: row.id) {
                        AppUI.Toggle(label: "", isOn: selection)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    } else {
                        Color.clear
                            .frame(width: 16, height: 16)
                    }
                }
                .width(min: 38, ideal: 44, max: 48)

                TableColumn("Data") { row in
                    Text(GranaDateFormat.fullDate(row.date))
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                }
                .width(min: 128, ideal: 148, max: 172)

                TableColumn("Descrição") { row in
                    HStack(spacing: AppUI.Theme.Spacing.sm) {
                        if let currentResolution {
                            InstitutionIcon(
                                kind: bankKind(currentResolution.accountId) ?? .other,
                                size: 22
                            )
                        }
                        Text(row.description)
                            .font(AppUI.Theme.Typography.subheadlineEmphasis)
                            .foregroundStyle(AppUI.Theme.Palette.ink)
                            .lineLimit(1)
                    }
                }

                TableColumn("Situação") { row in
                    if let status = row.status {
                        ImportWizardTableStatusBadge(status: status)
                    } else {
                        Text("Importar")
                            .font(AppUI.Theme.Typography.caption1Emphasis)
                            .foregroundStyle(AppUI.Theme.Palette.tealDeep)
                    }
                }
                .width(min: 120, ideal: 146, max: 180)

                TableColumn("Valor") { row in
                    Text(row.amount.formatted(.currency(code: "BRL")))
                        .font(AppUI.Theme.Typography.moneySubheadline)
                        .foregroundStyle(amountColor(for: row.amountKind))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 140, ideal: 140, max: 160)
            } filterBar: {
                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
                    if resolutions.count > 1 {
                        AppUI.Selector(
                            label: "Extrato",
                            options: Array(resolutions.enumerated()).map { index, statement in
                                .init(id: statement.id, title: tabLabel(for: index))
                            },
                            selection: selectedBinding,
                            style: .segmented
                        )
                    }

                    TransactionsSelectionRow(
                        summary: "\(currentSelectedCount) de \(currentEligibleCount) selecionadas",
                        allSelected: allSelected,
                        onToggleAll: toggleAll(to:)
                    )
                }
            }
        }
    }

    private var selectedBinding: Binding<OFXStatementResolution.ID?> {
        Binding(
            get: { selectedStatementID ?? resolutions.first?.id },
            set: { selectedStatementID = $0 }
        )
    }

    private func selectionBinding(for rowID: UUID) -> Binding<Bool>? {
        guard resolutions.indices.contains(selectedIndex),
              let rowIndex = resolutions[selectedIndex].rows.firstIndex(where: { $0.id == rowID }),
              !resolutions[selectedIndex].rows[rowIndex].isDuplicate else {
            return nil
        }
        return Binding(
            get: { resolutions[selectedIndex].rows[rowIndex].selected },
            set: { resolutions[selectedIndex].rows[rowIndex].selected = $0 }
        )
    }

    private func toggleAll(to value: Bool) {
        guard resolutions.indices.contains(selectedIndex) else { return }
        for rowIndex in resolutions[selectedIndex].rows.indices where !resolutions[selectedIndex].rows[rowIndex].isDuplicate {
            resolutions[selectedIndex].rows[rowIndex].selected = value
        }
    }

    private func tabLabel(for index: Int) -> String {
        "Extrato \(index + 1)"
    }

    private func amountColor(for kind: TransactionRow.AmountKind) -> Color {
        switch kind {
        case .incoming:
            .income
        case .transfer:
            .transfer
        case .outgoing:
            AppUI.Theme.Palette.ink
        }
    }
}

private struct OFXTransactionTableRow: Identifiable {
    let id: UUID
    let date: Date
    let description: String
    let amount: Decimal
    let amountKind: TransactionRow.AmountKind
    let status: TransactionRow.Status?
}
