import ComposableArchitecture
import SwiftUI

struct TransactionsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: StoreOf<TransactionsFeature>?

    init(store: StoreOf<TransactionsFeature>? = nil) {
        _store = State(initialValue: store)
    }

    var body: some View {
        Group {
            if let store {
                TransactionsContentView(store: store)
                    .environment(environment)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if store == nil {
                store = Store(initialState: TransactionsFeature.State()) {
                    TransactionsFeature()
                } withDependencies: {
                    $0.transactionsClient = .live(container: environment.container)
                }
            }
        }
    }
}

private struct TransactionsContentView: View {
    private static let ptBR = Locale(identifier: "pt_BR")

    @Bindable var store: StoreOf<TransactionsFeature>
    @Environment(\.calendar) private var calendar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sortOrder = [
        KeyPathComparator(\TransactionTableRow.occurredAt, order: .reverse),
    ]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
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
        .overlay {
            transactionFormDrawer
        }
        .animation(drawerAnimation, value: store.destination != nil)
        .sheet(isPresented: deleteConfirmationIsPresented) {
            if let transaction = store.pendingDelete {
                DeleteTransactionConfirmationView(
                    transaction: transaction,
                    impactMessage: store.state.deleteImpactMessage(for: transaction),
                    onCancel: { store.send(.deleteConfirmationDismissed) },
                    onDelete: { store.send(.deleteConfirmedButtonTapped) }
                )
            }
        }
        .task {
            await store.send(.task).finish()
        }
        .onChange(of: sortOrder) { _, newValue in
            let selectedSort = TransactionsSortMapper.map(newValue)
            guard selectedSort != store.tableSort else { return }
            store.send(.tableSortSelected(selectedSort))
        }
    }

    private var deleteConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { store.pendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    store.send(.deleteConfirmationDismissed)
                }
            }
        )
    }

    private var mainContent: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            FeatureScreenHeader(
                title: "Transações",
                subtitle: store.state.transactionsCountText(calendar: calendar)
            ) {
                HStack(spacing: GranaTheme.Spacing.sm) {
                    Button {
                        store.send(.addButtonTapped)
                    } label: {
                        Label("Adicionar", systemImage: AppIcon.add.systemImage)
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())
                }
            }

            GranaTable(tableRows, sortOrder: $sortOrder) {
                TableColumn("Instituição", value: \.institutionName) { row in
                    HStack(spacing: GranaTheme.Spacing.sm) {
                        InstitutionIcon(kind: row.institutionKind, size: 22)
                        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                            Text(row.institutionName)
                                .font(GranaTheme.Typography.subheadlineEmphasis)
                                .foregroundStyle(GranaTheme.Palette.ink)
                                .lineLimit(1)
                            Text(row.accountName)
                                .font(GranaTheme.Typography.caption1)
                                .foregroundStyle(GranaTheme.Palette.muted)
                                .lineLimit(1)
                        }
                    }
                }
                .width(min: 210, ideal: 240, max: 300)

                TableColumn("Data", value: \.occurredAt) { row in
                    Text(row.occurredAt.formatted(date: .numeric, time: .omitted))
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)
                }
                .width(min: 92, ideal: 110, max: 132)

                TableColumn("Descrição", value: \.description) { row in
                    Text(row.description)
                        .font(GranaTheme.Typography.subheadlineEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .lineLimit(1)
                }

                TableColumn("Categoria", value: \.categorySummary) { row in
                    HStack(spacing: GranaTheme.Spacing.xs) {
                        CategoryBadge(
                            category: store.state.category(for: row.transaction.categoryId),
                            icon: store.state.icon(for: row.transaction.categoryId),
                            iconOnly: true
                        )
                        Text(row.categorySummary)
                            .font(GranaTheme.Typography.footnoteEmphasis)
                            .foregroundStyle(GranaTheme.Palette.muted)
                            .lineLimit(1)
                    }
                }
                .width(min: 170, ideal: 220, max: 260)

                TableColumn("Valor", value: \.amount) { row in
                    accountingAmount(row.amount)
                        .foregroundStyle(amountColor(for: row.transaction))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 132, ideal: 148, max: 180)

                TableColumn("Ações") { row in
                    rowActions(row.transaction)
                }
                .width(min: 76, ideal: 92, max: 112)
            } filterBar: {
                TransactionsFilterBar(
                    searchText: $store.searchText,
                    bankFilterName: store.bankFilterName,
                    categoryFilterName: store.categoryFilterName,
                    periodFilterName: store.periodFilter.name,
                    kindFilterName: store.kindFilter.name,
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

    @ViewBuilder
    private var transactionFormDrawer: some View {
        if let formStore = $store.scope(\.destination, action: \.destination).editForm.wrappedValue {
            SideDrawer(
                onDismiss: {
                    formStore.send(.cancelButtonTapped)
                },
                content: {
                    TransactionFormView(store: formStore)
                }
            )
            .transition(drawerTransition)
        }
    }

    private var drawerTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }

    private var drawerAnimation: Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.35, bounce: 0.12)
    }

    private var tableRows: [TransactionTableRow] {
        store.state.filtered(calendar: calendar).map { transaction in
            TransactionTableRow(
                transaction: transaction,
                institutionName: institutionName(for: transaction),
                institutionKind: store.state.institutionKind(for: transaction),
                accountName: store.state.accountName(for: transaction),
                occurredAt: transaction.occurredAt,
                description: transaction.description,
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

        return HStack(spacing: GranaTheme.Spacing.sm) {
            Button {
                store.send(.editButtonTapped(transaction))
            } label: {
                Image(systemName: AppIcon.edit.systemImage)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
            .buttonStyle(.borderless)
            .disabled(!canMutate)
            .help(canMutate ? "Editar" : unsupportedMessage)

            Button(role: .destructive) {
                store.send(.deleteButtonTapped(transaction))
            } label: {
                Image(systemName: AppIcon.delete.systemImage)
                    .foregroundStyle(GranaTheme.Palette.muted)
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
                .locale(Self.ptBR)
        )
        return HStack(spacing: GranaTheme.Spacing.xxs) {
            Text("R$")
                .foregroundStyle(GranaTheme.Palette.muted)
            Spacer(minLength: GranaTheme.Spacing.xxs)
            Text(number)
        }
        .font(GranaTheme.Typography.moneySubheadline)
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

private struct DeleteTransactionConfirmationView: View {
    let transaction: Transaction
    let impactMessage: String
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            GranaBackground()

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xl) {
                header
                if !impactMessage.isEmpty {
                    messageBlock
                }
                Spacer(minLength: GranaTheme.Spacing.none)
                actions
            }
            .padding(GranaTheme.Spacing.xl)
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 460, idealWidth: 460, maxWidth: 460, minHeight: 280)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            HStack(spacing: GranaTheme.Spacing.sm) {
                Image(systemName: AppIcon.delete.systemImage)
                    .font(.system(size: GranaTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.red)

                Text("Apagar transação?")
                    .font(GranaTheme.Typography.title3)
                    .foregroundStyle(GranaTheme.Palette.ink)
            }

            Text(transactionSummary)
                .font(GranaTheme.Typography.bodyEmphasis)
                .foregroundStyle(GranaTheme.Palette.ink)
        }
    }

    private var messageBlock: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
            Image(systemName: AppIcon.warning.systemImage)
                .font(.system(size: GranaTheme.IconSize.small))
                .foregroundStyle(GranaTheme.Palette.amber)
                .padding(.top, GranaTheme.Spacing.xxs)

            Text(impactMessage)
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(GranaTheme.Spacing.md)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
    }

    private var actions: some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            Spacer(minLength: GranaTheme.Spacing.none)

            Button("Cancelar", action: onCancel)
                .buttonStyle(GranaSecondaryButtonStyle())

            Button("Apagar", action: onDelete)
                .buttonStyle(GranaDestructiveButtonStyle())
        }
    }

    private var transactionSummary: String {
        "\(transaction.description) - \(transaction.amount.formatted(.currency(code: "BRL")))"
    }
}

private struct TransactionTableRow: Identifiable {
    let transaction: Transaction
    let institutionName: String
    let institutionKind: InstitutionKind
    let accountName: String
    let occurredAt: Date
    let description: String
    let categorySummary: String
    let amount: Decimal

    var id: UUID {
        transaction.id
    }
}

private enum TransactionsSortMapper {
    static func map(_ comparators: [KeyPathComparator<TransactionTableRow>]) -> TransactionsTableSort {
        guard let comparator = comparators.first else { return TransactionsTableSort.occurredAtDescending }

        switch comparator.keyPath {
        case \TransactionTableRow.institutionName:
            return comparator.order == .forward
                ? TransactionsTableSort.institutionAscending
                : TransactionsTableSort.institutionDescending
        case \TransactionTableRow.occurredAt:
            return comparator.order == .forward
                ? TransactionsTableSort.occurredAtAscending
                : TransactionsTableSort.occurredAtDescending
        case \TransactionTableRow.description:
            return comparator.order == .forward
                ? TransactionsTableSort.descriptionAscending
                : TransactionsTableSort.descriptionDescending
        case \TransactionTableRow.categorySummary:
            return comparator.order == .forward
                ? TransactionsTableSort.categoryAscending
                : TransactionsTableSort.categoryDescending
        case \TransactionTableRow.amount:
            return comparator.order == .forward
                ? TransactionsTableSort.amountAscending
                : TransactionsTableSort.amountDescending
        default:
            return TransactionsTableSort.occurredAtDescending
        }
    }
}

private struct TransactionsFilterBar: View {
    @Binding var searchText: String
    let bankFilterName: String
    let categoryFilterName: String
    let periodFilterName: String
    let kindFilterName: String
    let availableBanks: [Institution]
    let categories: [Category]
    let onBankSelected: (TransactionBankFilter) -> Void
    let onCategorySelected: (TransactionCategoryFilter) -> Void
    let onPeriodSelected: (TransactionPeriodFilter) -> Void
    let onKindSelected: (TransactionKindFilter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            searchField

            HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                filterMenu(
                    title: "Banco",
                    value: bankFilterName,
                    icon: AppIcon.sidebarAccounts.systemImage
                ) {
                    Button("Todos bancos") {
                        onBankSelected(.all)
                    }
                    Divider()
                    ForEach(availableBanks) { institution in
                        Button(institution.name) {
                            onBankSelected(.bank(institution.id))
                        }
                    }
                }

                filterMenu(
                    title: "Categoria",
                    value: categoryFilterName,
                    icon: "tag"
                ) {
                    Button("Todas categorias") {
                        onCategorySelected(.all)
                    }
                    Divider()
                    ForEach(categories) { category in
                        Button(category.name) {
                            onCategorySelected(.category(category.id))
                        }
                    }
                }

                filterMenu(
                    title: "Período",
                    value: periodFilterName,
                    icon: "calendar"
                ) {
                    ForEach(TransactionPeriodFilter.allCases) { filter in
                        Button(filter.name) {
                            onPeriodSelected(filter)
                        }
                    }
                }

                filterMenu(
                    title: "Tipo",
                    value: kindFilterName,
                    icon: "arrow.left.arrow.right.circle"
                ) {
                    ForEach(TransactionKindFilter.allCases) { filter in
                        Button(filter.name) {
                            onKindSelected(filter)
                        }
                    }
                }

                Spacer(minLength: GranaTheme.Spacing.none)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(GranaTheme.Palette.tealDeep)

            TextField("Descrição, categoria ou conta", text: $searchText)
                .textFieldStyle(.plain)
                .font(GranaTheme.Typography.subheadlineEmphasis)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(GranaTheme.Palette.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, GranaTheme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GranaTheme.Palette.paper.opacity(0.92))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GranaTheme.Palette.line, lineWidth: 1)
        }
    }

    private func filterMenu<Content: View>(
        title: String,
        value: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
            Text(title)
                .font(GranaTheme.Typography.caption2Emphasis)
                .foregroundStyle(GranaTheme.Palette.muted)

            Menu {
                content()
            } label: {
                HStack(spacing: GranaTheme.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                        .foregroundStyle(GranaTheme.Palette.tealDeep)

                    Text(value)
                        .font(GranaTheme.Typography.footnoteEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .lineLimit(1)

                    Spacer(minLength: GranaTheme.Spacing.none)

                    Image(systemName: "chevron.down")
                        .font(.system(size: GranaTheme.IconSize.micro, weight: .semibold))
                        .foregroundStyle(GranaTheme.Palette.muted)
                }
                .padding(.horizontal, GranaTheme.Spacing.sm)
                .frame(minWidth: 180, minHeight: 40, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(GranaTheme.Palette.paper.opacity(0.92))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GranaTheme.Palette.line, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
