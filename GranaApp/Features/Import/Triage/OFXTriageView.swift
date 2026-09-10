import AppUI
import ComposableArchitecture
import SwiftUI

struct OFXTriageView<SidebarActions: View>: View {
    @Bindable var store: StoreOf<OFXTriageFeature>
    @State private var selectedStatementID: OFXStatementResolution.ID?
    let sidebarActions: () -> SidebarActions

    private var selectedStatementIndex: Int {
        guard let selectedStatementID,
              let index = store.state.resolutions.firstIndex(where: { $0.id == selectedStatementID })
        else { return 0 }
        return index
    }

    var body: some View {
        AppUI.Form.Shell {
            AppUI.Form.Header(
                title: "Triagem",
                subtitle: "Selecione a conta e as transações que serão importadas"
            ) {
                ImportWizardInlineSteps(steps: ImportWizardStage.presentedSteps(currentStage: .triage))
            }

            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
                if store.state.resolutions.indices.contains(selectedStatementIndex) {
                    OFXAccountInfoSection(store: store, statementIndex: selectedStatementIndex)
                }

                OFXTransactionsListSection(
                    resolutions: Binding(
                        get: { store.state.resolutions },
                        set: { store.send(.resolutionsUpdated($0)) }
                    ),
                    selectedStatementID: $selectedStatementID
                )
            }
            .padding(.horizontal, AppUI.Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            AppUI.Form.Actions {
                sidebarActions()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

private struct OFXAccountInfoSection: View {
    @Bindable var store: StoreOf<OFXTriageFeature>
    let statementIndex: Int

    private var resolution: OFXStatementResolution? {
        store.state.resolutions.indices.contains(statementIndex) ? store.state.resolutions[statementIndex] : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
            AppUI.Form.SectionHeader(title: "Conta de destino")

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OFXTransactionsListSection: View {
    private static let numberLocale = Locale(identifier: "pt_BR")

    @Binding var resolutions: [OFXStatementResolution]
    @Binding var selectedStatementID: OFXStatementResolution.ID?

    private var selectedIndex: Int {
        guard let selectedStatementID,
              let index = resolutions.firstIndex(where: { $0.id == selectedStatementID })
        else { return 0 }
        return index
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
                badge: $0.isDuplicate ? .duplicate : nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.date < rhs.date
        }
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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
            AppUI.Form.SectionHeader(title: "Transações")

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

            AppUI.Table(tableRows) {
                TableColumn("") { row in
                    if let selection = selectionBinding(for: row.id) {
                        AppUI.Toggle(label: "", isOn: selection)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    } else {
                        AppUI.Toggle(label: "", isOn: .constant(false))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .disabled(true)
                            .accessibilityLabel("Linha não selecionável")
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
                    HStack(spacing: AppUI.Theme.Spacing.xs) {
                        if let badge = row.badge {
                            ImportWizardDescriptionBadge(status: badge)
                        }

                        Text(row.description)
                            .font(AppUI.Theme.Typography.subheadlineEmphasis)
                            .foregroundStyle(AppUI.Theme.Palette.ink)
                            .lineLimit(1)
                    }
                }

                TableColumn("Valor") { row in
                    accountingAmount(row.amount)
                        .foregroundStyle(amountColor(for: row.amountKind))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 140, ideal: 140, max: 160)
            }
            .overlay(alignment: .topLeading) {
                allRowsSelectionToggle
                    .padding(.leading, AppUI.Theme.Spacing.md)
                    .padding(.top, AppUI.Theme.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var allRowsSelectionToggle: some View {
        AppUI.Toggle(label: "", isOn: Binding(
            get: { allSelected },
            set: { toggleAll(to: $0) }
        ))
        .toggleStyle(.checkbox)
        .labelsHidden()
        .accessibilityLabel(allSelected ? "Desmarcar todas" : "Marcar todas")
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
              !resolutions[selectedIndex].rows[rowIndex].isDuplicate
        else {
            return nil
        }
        return Binding(
            get: { resolutions[selectedIndex].rows[rowIndex].selected },
            set: { resolutions[selectedIndex].rows[rowIndex].selected = $0 }
        )
    }

    private func toggleAll(to value: Bool) {
        guard resolutions.indices.contains(selectedIndex) else { return }
        for rowIndex in resolutions[selectedIndex].rows.indices {
            guard !resolutions[selectedIndex].rows[rowIndex].isDuplicate else { continue }
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
            .expense
        }
    }

    private func accountingAmount(_ amount: Decimal) -> some View {
        let number = amount.formatted(
            .number
                .precision(.fractionLength(2))
                .locale(Self.numberLocale)
        )
        return HStack(spacing: AppUI.Theme.Spacing.xxs) {
            Text("R$")
                .foregroundStyle(AppUI.Theme.Palette.muted)
            Spacer(minLength: AppUI.Theme.Spacing.xxs)
            Text(number)
        }
        .font(AppUI.Theme.Typography.moneySubheadline)
    }
}

private struct OFXTransactionTableRow: Identifiable {
    let id: UUID
    let date: Date
    let description: String
    let amount: Decimal
    let amountKind: TransactionRow.AmountKind
    let badge: TransactionRow.Status?
}
