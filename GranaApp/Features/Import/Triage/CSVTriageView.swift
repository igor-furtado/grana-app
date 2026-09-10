import AppUI
import ComposableArchitecture
import SwiftUI

private let csvTriageNumberLocale = Locale(identifier: "pt_BR")

struct CSVTriageView<SidebarActions: View>: View {
    @Bindable var store: StoreOf<CSVTriageFeature>
    @Binding var resolution: CSVStatementResolution
    let onNegativeSelectionChanged: (UUID, Bool) -> Void
    let sidebarActions: () -> SidebarActions

    private var eligibleSelectionCount: Int {
        resolution.rows.filter { !$0.isDuplicate }.count
            + resolution.negativeRows.count
    }

    private var allSelected: Bool {
        guard eligibleSelectionCount > 0 else { return false }
        let purchasesSelected = resolution.rows.filter { !$0.isDuplicate && $0.selected }.count
        let negativesSelected = resolution.negativeRows.filter(\.selected).count
        return purchasesSelected + negativesSelected == eligibleSelectionCount
    }

    private func installmentLabel(for row: CSVPreviewRow) -> String? {
        guard row.raw.purchaseType == .installment,
              let installmentIndex = row.raw.installmentIndex,
              let installmentCount = row.raw.installmentCount
        else {
            return nil
        }
        return "Parcela \(installmentIndex)/\(installmentCount)"
    }

    private func negativeBadge(for row: CSVNegativePreviewRow) -> TransactionRow.Status {
        switch row.raw.kind {
        case .payment:
            .init(label: "Pagamento", tint: .neutral)
        case .balance:
            .init(label: "Saldo", tint: .info)
        }
    }

    @ViewBuilder
    private func selectionCell(for row: CSVTransactionTableRow) -> some View {
        if let selection = selectionBinding(for: row) {
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

    private func toggleAll(to value: Bool) {
        for index in resolution.rows.indices where !resolution.rows[index].isDuplicate {
            resolution.rows[index].selected = value
        }

        for index in resolution.negativeRows.indices {
            onNegativeSelectionChanged(resolution.negativeRows[index].id, value)
        }
    }

    private func selectionBinding(for row: CSVTransactionTableRow) -> Binding<Bool>? {
        switch row.kind {
        case .purchase:
            guard let index = resolution.rows.firstIndex(where: { $0.id == row.rowID }),
                  !resolution.rows[index].isDuplicate
            else {
                return nil
            }
            return $resolution.rows[index].selected
        case .balance, .payment:
            guard let index = resolution.negativeRows.firstIndex(where: { $0.id == row.rowID }) else {
                return nil
            }
            return Binding(
                get: { resolution.negativeRows[index].selected },
                set: { onNegativeSelectionChanged(resolution.negativeRows[index].id, $0) }
            )
        }
    }

    private var tableRows: [CSVTransactionTableRow] {
        let purchaseRows = resolution.rows.map {
            CSVTransactionTableRow(
                id: "purchase-\($0.id.uuidString)",
                rowID: $0.id,
                date: $0.raw.date,
                description: $0.raw.description,
                installmentLabel: installmentLabel(for: $0),
                badge: $0.isDuplicate ? .duplicate : nil,
                amount: $0.raw.amount,
                kind: .purchase
            )
        }
        let negativeRows = resolution.negativeRows.map {
            CSVTransactionTableRow(
                id: "negative-\($0.id.uuidString)",
                rowID: $0.id,
                date: $0.raw.date,
                description: $0.raw.description,
                installmentLabel: nil,
                badge: negativeBadge(for: $0),
                amount: abs($0.raw.amount),
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

    var body: some View {
        AppUI.Form.Shell {
            AppUI.Form.Header(
                title: "Triagem",
                subtitle: "Selecione a conta e as transações que serão importadas"
            ) {
                ImportWizardInlineSteps(steps: ImportWizardStage.presentedSteps(currentStage: .triage))
            }

            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
                accountSection
                transactionsSection
            }
            .padding(.horizontal, AppUI.Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            AppUI.Form.Actions {
                sidebarActions()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
            AppUI.Form.SectionHeader(title: "Conta de destino")

            AppUI.Selector(
                placeholder: "Selecione…",
                options: store.state.creditCardAccounts.map {
                    .init(id: $0.id, title: store.state.accountLabel(for: $0))
                },
                selection: Binding(
                    get: { store.state.resolution.accountId },
                    set: { store.send(.accountSelected($0)) }
                ),
                icon: "creditcard"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
            AppUI.Form.SectionHeader(title: "Transações")

            AppUI.Table(tableRows) {
                TableColumn("") { row in
                    selectionCell(for: row)
                }
                .width(min: 35, ideal: 35, max: 48)

                TableColumn("Data") { row in
                    Text(GranaDateFormat.fullDate(row.date))
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                }
                .width(min: 128, ideal: 148, max: 172)

                TableColumn("Descrição") { row in
                    descriptionCell(for: row)
                }

                TableColumn("Valor") { row in
                    accountingAmount(row.amount)
                        .foregroundStyle(amountColor(for: row.kind))
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

    private func descriptionCell(for row: CSVTransactionTableRow) -> some View {
        HStack(spacing: AppUI.Theme.Spacing.xs) {
            if let badge = row.badge {
                ImportWizardDescriptionBadge(status: badge)
            }

            if let installmentLabel = row.installmentLabel {
                Text(installmentLabel)
                    .font(AppUI.Theme.Typography.caption1)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
                    .lineLimit(1)
            }

            Text(row.description)
                .font(AppUI.Theme.Typography.subheadlineEmphasis)
                .foregroundStyle(AppUI.Theme.Palette.ink)
                .lineLimit(1)
        }
    }

    private func accountingAmount(_ amount: Decimal) -> some View {
        let number = amount.formatted(
            .number
                .precision(.fractionLength(2))
                .locale(csvTriageNumberLocale)
        )
        return HStack(spacing: AppUI.Theme.Spacing.xxs) {
            Text("R$")
                .foregroundStyle(AppUI.Theme.Palette.muted)
            Spacer(minLength: AppUI.Theme.Spacing.xxs)
            Text(number)
        }
        .font(AppUI.Theme.Typography.moneySubheadline)
    }

    private func amountColor(for kind: CSVTransactionTableRow.Kind) -> Color {
        switch kind {
        case .purchase:
            .expense
        case .balance:
            .income
        case .payment:
            AppUI.Theme.Palette.ink
        }
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
    let installmentLabel: String?
    let badge: TransactionRow.Status?
    let amount: Decimal
    let kind: Kind
}
