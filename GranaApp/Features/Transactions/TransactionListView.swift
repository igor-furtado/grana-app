import ComposableArchitecture
import SwiftUI
import AppUI

struct TransactionListView: View {
    private static let numberLocale = Locale(identifier: "pt_BR")

    @Bindable var store: StoreOf<TransactionListFeature>
    @Environment(\.calendar) private var calendar
    @State private var sortOrder = TransactionsSortMapper.comparators(for: .occurredAtDescending)

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.none) {
            mainContent
                .overlay {
                    if tableRows.isEmpty && !store.isLoading {
                        EmptyStateView(
                            "Sem transações ainda",
                            icon: .sidebarTransactions,
                            description: "Adicione uma manualmente ou importe um extrato."
                        )
                    }
                }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
        .onChange(of: sortOrder) { _, newValue in
            let selectedSort = TransactionsSortMapper.map(newValue)
            guard selectedSort != store.tableSort else { return }
            store.send(.tableSortSelected(selectedSort))
        }
    }

    private var mainContent: some View {
        VStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Layout.ScreenHeader(
                title: "Transações",
                subtitle: store.state.transactionsCountText(calendar: calendar)
            ) {
                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    Button {
                        store.send(.addButtonTapped)
                    } label: {
                        Label("Nova transação", systemImage: AppUI.Icon.add.systemImage)
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())
                }
            }

            AppUI.Table(tableRows, sortOrder: $sortOrder) {
                TableColumn("Instituição", value: \.institutionName) { row in
                    HStack(spacing: AppUI.Theme.Spacing.sm) {
                        InstitutionIcon(kind: row.institutionKind, size: 24)
                        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                            Text(row.institutionName)
                                .font(AppUI.Theme.Typography.subheadlineEmphasis)
                                .foregroundStyle(AppUI.Theme.Palette.ink)
                                .lineLimit(1)
                            Text(row.accountName)
                                .font(AppUI.Theme.Typography.caption1)
                                .foregroundStyle(AppUI.Theme.Palette.muted)
                                .lineLimit(1)
                        }
                    }
                }
                .width(min: 210, ideal: 240, max: 240)

                TableColumn("Data", value: \.occurredAt) { row in
                    Text(GranaDateFormat.fullDate(row.occurredAt))
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                }
                .width(min: 110, ideal: 140, max: 140)

                TableColumn("Descrição", value: \.description) { row in
                    Text(row.description)
                        .font(AppUI.Theme.Typography.subheadlineEmphasis)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
                        .lineLimit(1)
                }

                TableColumn("Categoria", value: \.categorySummary) { row in
                    HStack(spacing: AppUI.Theme.Spacing.xs) {
                        CategoryBadge(
                            category: store.state.category(for: row.transaction.categoryId),
                            icon: store.state.icon(for: row.transaction.categoryId),
                            iconOnly: true
                        )
                        Text(row.categoryDisplayName)
                            .font(AppUI.Theme.Typography.footnoteEmphasis)
                            .foregroundStyle(AppUI.Theme.Palette.muted)
                            .lineLimit(1)
                    }
                    .help(row.categoryName)
                }
                .width(min: 170, ideal: 220, max: 220)

                TableColumn("Valor", value: \.amount) { row in
                    accountingAmount(row.amount)
                        .foregroundStyle(amountColor(for: row.transaction))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 140, ideal: 140, max: 180)

                TableColumn("Ações") { row in
                    rowActions(row.transaction)
                }
                .width(min: 70, ideal: 70, max: 70)
            } filterBar: {
                TransactionsFilterBar(
                    searchText: $store.searchText,
                    bankFilter: store.bankFilter,
                    categoryFilter: store.categoryFilter,
                    periodFilter: store.periodFilter,
                    kindFilter: store.kindFilter,
                    availableBanks: store.availableBanks,
                    categories: store.sortedRootCategories,
                    onBankSelected: { store.send(.bankFilterSelected($0)) },
                    onCategorySelected: { store.send(.categoryFilterSelected($0)) },
                    onPeriodSelected: { store.send(.periodFilterSelected($0)) },
                    onKindSelected: { store.send(.kindFilterSelected($0)) }
                )
            }
        }
    }

    private var tableRows: [TransactionTableRow] {
        store.state.visibleTransactions(calendar: calendar).map { transaction in
            TransactionTableRow(
                transaction: transaction,
                institutionName: institutionName(for: transaction),
                institutionKind: store.state.institutionKind(for: transaction),
                accountName: store.state.accountName(for: transaction),
                occurredAt: transaction.occurredAt,
                description: transaction.description,
                categoryName: store.state.categoryName(for: transaction),
                categoryDisplayName: store.state.subcategoryName(for: transaction)
                    ?? store.state.categoryName(for: transaction),
                categorySummary: store.state.categorySummary(for: transaction),
                amount: transaction.amount
            )
        }
    }

    private func institutionName(for transaction: Transaction) -> String {
        guard let account = store.state.account(for: transaction.accountId),
              let institutionId = account.institutionId,
              let institution = store.state.institution(for: institutionId)
        else {
            return "Sem instituição"
        }
        return institution.name
    }

    private func rowActions(_ transaction: Transaction) -> some View {
        let canMutate = store.state.supportsBasicMutation(for: transaction)
        let unsupportedMessage = "A edição desta transação não está disponível nesta configuração."

        return HStack(spacing: AppUI.Theme.Spacing.sm) {
            Button {
                store.send(.editButtonTapped(transaction))
            } label: {
                Image(systemName: AppUI.Icon.edit.systemImage)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }
            .buttonStyle(.borderless)
            .disabled(!canMutate)
            .help(canMutate ? "Editar" : unsupportedMessage)

            Button(role: .destructive) {
                store.send(.deleteButtonTapped(transaction))
            } label: {
                Image(systemName: AppUI.Icon.delete.systemImage)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }
            .buttonStyle(.borderless)
            .disabled(!canMutate)
            .help(canMutate ? "Apagar" : unsupportedMessage)
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

    private func amountColor(for transaction: Transaction) -> Color {
        switch store.state.category(for: transaction.categoryId)?.kind {
        case .income: return .income
        case .transfer: return .transfer
        case .expense: return .expense
        case .none: return .primary
        }
    }
}

private struct TransactionTableRow: Identifiable {
    let transaction: Transaction
    let institutionName: String
    let institutionKind: InstitutionKind
    let accountName: String
    let occurredAt: Date
    let description: String
    let categoryName: String
    let categoryDisplayName: String
    let categorySummary: String
    let amount: Decimal

    var id: UUID {
        transaction.id
    }
}

private enum TransactionsSortMapper {
    static func map(_ comparators: [KeyPathComparator<TransactionTableRow>]) -> TransactionsTableSort {
        guard let comparator = comparators.first else { return .occurredAtDescending }

        switch comparator.keyPath {
        case \TransactionTableRow.institutionName:
            return comparator.order == .forward ? .institutionAscending : .institutionDescending
        case \TransactionTableRow.occurredAt:
            return comparator.order == .forward ? .occurredAtAscending : .occurredAtDescending
        case \TransactionTableRow.description:
            return comparator.order == .forward ? .descriptionAscending : .descriptionDescending
        case \TransactionTableRow.categorySummary:
            return comparator.order == .forward ? .categoryAscending : .categoryDescending
        case \TransactionTableRow.amount:
            return comparator.order == .forward ? .amountAscending : .amountDescending
        default:
            return .occurredAtDescending
        }
    }

    static func comparators(for sort: TransactionsTableSort) -> [KeyPathComparator<TransactionTableRow>] {
        switch sort {
        case .institutionAscending:
            [KeyPathComparator(\.institutionName, order: .forward)]
        case .institutionDescending:
            [KeyPathComparator(\.institutionName, order: .reverse)]
        case .occurredAtAscending:
            [KeyPathComparator(\.occurredAt, order: .forward)]
        case .occurredAtDescending:
            [KeyPathComparator(\.occurredAt, order: .reverse)]
        case .descriptionAscending:
            [KeyPathComparator(\.description, order: .forward)]
        case .descriptionDescending:
            [KeyPathComparator(\.description, order: .reverse)]
        case .categoryAscending:
            [KeyPathComparator(\.categorySummary, order: .forward)]
        case .categoryDescending:
            [KeyPathComparator(\.categorySummary, order: .reverse)]
        case .amountAscending:
            [KeyPathComparator(\.amount, order: .forward)]
        case .amountDescending:
            [KeyPathComparator(\.amount, order: .reverse)]
        }
    }
}

private struct TransactionsFilterBar: View {
    @Binding var searchText: String
    let bankFilter: TransactionBankFilter
    let categoryFilter: TransactionCategoryFilter
    let periodFilter: TransactionPeriodFilter
    let kindFilter: TransactionKindFilter
    let availableBanks: [Institution]
    let categories: [Category]
    let onBankSelected: (TransactionBankFilter) -> Void
    let onCategorySelected: (TransactionCategoryFilter) -> Void
    let onPeriodSelected: (TransactionPeriodFilter) -> Void
    let onKindSelected: (TransactionKindFilter) -> Void

    var body: some View {
        AppUI.TableFilterBar {
            searchField

            AppUI.Selector(
                label: "Banco",
                options: availableBanks.map { .init(id: $0.id, title: $0.name) },
                selection: bankSelection,
                includesNoneOption: true,
                noneOptionTitle: "Todos bancos",
                icon: AppUI.Icon.sidebarAccounts.systemImage
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            AppUI.Selector(
                label: "Categoria",
                options: categories.map { .init(id: $0.id, title: $0.name) },
                selection: categorySelection,
                includesNoneOption: true,
                noneOptionTitle: "Todas categorias",
                icon: AppUI.Icon.sidebarCategories.systemImage
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            AppUI.Selector(
                label: "Período",
                options: TransactionPeriodFilter.allCases.map { .init(id: $0, title: $0.name) },
                selection: periodSelection,
                icon: AppUI.Icon.sidebarAccounts.systemImage
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            AppUI.Selector(
                label: "Tipo",
                options: TransactionKindFilter.allCases.map { .init(id: $0, title: $0.name) },
                selection: kindSelection,
                icon: "line.3.horizontal.decrease.circle"
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: AppUI.Theme.Spacing.none)
        }
    }

    private var searchField: some View {
        AppUI.TextField(
            label: "Buscar transação",
            text: $searchText,
            placeholder: "Descrição, categoria ou conta",
            leadingSystemImage: "magnifyingglass",
            showsClearButton: true,
            font: AppUI.Theme.Typography.subheadlineEmphasis,
            textAlignment: .leading
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bankSelection: Binding<UUID?> {
        Binding(
            get: {
                if case let .bank(id) = bankFilter {
                    return id
                }
                return nil
            },
            set: { id in
                onBankSelected(id.map(TransactionBankFilter.bank) ?? .all)
            }
        )
    }

    private var categorySelection: Binding<UUID?> {
        Binding(
            get: {
                if case let .category(id) = categoryFilter {
                    return id
                }
                return nil
            },
            set: { id in
                onCategorySelected(id.map(TransactionCategoryFilter.category) ?? .all)
            }
        )
    }

    private var periodSelection: Binding<TransactionPeriodFilter> {
        Binding(
            get: { periodFilter },
            set: { onPeriodSelected($0) }
        )
    }

    private var kindSelection: Binding<TransactionKindFilter> {
        Binding(
            get: { kindFilter },
            set: { onKindSelected($0) }
        )
    }
}
