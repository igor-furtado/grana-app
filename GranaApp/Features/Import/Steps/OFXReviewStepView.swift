import ComposableArchitecture
import SwiftUI

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
        ImportWizardStageScaffold {
            ImportWizardSplitLayout(currentStage: .triage) {
                VStack(spacing: GranaTheme.Spacing.md) {
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
                Picker(
                    "Conta de destino",
                    selection: Binding(
                        get: { resolution?.accountId },
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
            )
        ) {
            if let resolution {
                HStack(spacing: GranaTheme.Spacing.md) {
                    ImportWizardInfoRow(label: "Banco") {
                        Text(resolution.ofxBankLabel)
                    }

                    ImportWizardInfoRow(label: "Conta do extrato") {
                        Text(resolution.ofxAccountLabel)
                    }
                }
                .padding(.horizontal, GranaTheme.Spacing.md)
                .padding(.bottom, GranaTheme.Spacing.md)
            }
        }
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

    private var orderedRowIndices: [Int] {
        guard let currentResolution else { return [] }
        return currentResolution.rows.indices.sorted { lhs, rhs in
            let leftDate = currentResolution.rows[lhs].derived.occurredAt
            let rightDate = currentResolution.rows[rhs].derived.occurredAt
            if leftDate == rightDate {
                return lhs < rhs
            }
            return leftDate < rightDate
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
            VStack(spacing: GranaTheme.Spacing.none) {
                if resolutions.count > 1 {
                    Picker("Extrato", selection: selectedBinding) {
                        ForEach(Array(resolutions.enumerated()), id: \.element.id) { index, resolution in
                            Text(tabLabel(for: index)).tag(Optional.some(resolution.id))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, GranaTheme.Spacing.md)
                    .padding(.vertical, GranaTheme.Spacing.sm)
                }

                TransactionsSelectionRow(
                    summary: "\(currentSelectedCount) de \(currentEligibleCount) selecionadas",
                    allSelected: allSelected,
                    onToggleAll: toggleAll(to:)
                )
                Divider()

                ScrollView {
                    LazyVStack(spacing: GranaTheme.Spacing.none) {
                        ForEach(orderedRowIndices, id: \.self) { rowIndex in
                            if let currentResolution {
                                OFXRowView(
                                    row: binding(for: rowIndex),
                                    institutionKind: bankKind(currentResolution.accountId)
                                )
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

    private var selectedBinding: Binding<OFXStatementResolution.ID?> {
        Binding(
            get: { selectedStatementID ?? resolutions.first?.id },
            set: { selectedStatementID = $0 }
        )
    }

    private func binding(for rowIndex: Int) -> Binding<OFXPreviewRow> {
        Binding(
            get: { resolutions[selectedIndex].rows[rowIndex] },
            set: { resolutions[selectedIndex].rows[rowIndex] = $0 }
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
}

private struct OFXRowView: View {
    @Binding var row: OFXPreviewRow
    let institutionKind: InstitutionKind?

    var body: some View {
        TransactionRow(
            selection: row.isDuplicate ? nil : $row.selected,
            institutionKind: institutionKind,
            description: primaryDescription,
            memo: nil,
            date: row.derived.occurredAt,
            amount: row.derived.amount.magnitude,
            amountKind: row.derived.amount < 0 ? .outgoing : .incoming,
            status: row.isDuplicate ? .duplicate : nil
        )
    }

    private var primaryDescription: String {
        row.derived.description
    }
}
