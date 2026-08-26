import ComposableArchitecture
import SwiftUI

struct TransactionsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: StoreOf<TransactionsFeature>?

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
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            mainContent
                .overlay {
                    if store.transactions.isEmpty && !store.isLoading {
                        EmptyStateView(
                            "Sem transações ainda",
                            icon: .sidebarTransactions,
                            description: "Adicione uma manualmente ou importe um extrato."
                        )
                    }
                }

            if store.hasMoreTransactions || store.isLoadingMoreTransactions {
                Divider()
                HStack {
                    Spacer()
                    if store.isLoadingMoreTransactions {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Carregar mais") {
                            store.send(.loadMoreButtonTapped)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, GranaTheme.Spacing.sm)
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).addForm
        ) { formStore in
            TransactionFormView(store: formStore)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).editForm
        ) { formStore in
            TransactionFormView(store: formStore)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).importFlow
        ) { _ in
            ImportView()
                .environment(environment)
        }
        .confirmationDialog($store.scope(\.confirmationDialog, action: \.confirmationDialog))
        .task {
            await store.send(.task).finish()
        }
    }

    private var mainContent: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            transactionsHeader
            transactionsContentSection
        }
        .granaPagePadding()
    }

    private var transactionsHeader: some View {
        TransactionsHeaderView(
            searchText: $store.searchText,
            countText: store.state.transactionsCountText(calendar: calendar),
            onImport: { store.send(.importButtonTapped) },
            onAdd: { store.send(.addButtonTapped) },
            bankControl: AnyView(headerBankMenu),
            periodControl: AnyView(headerPeriodMenu),
            categoryControl: AnyView(headerCategoryMenu),
            kindControl: AnyView(headerKindMenu)
        )
    }

    private var transactionsContentSection: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            transactionsTableCard {
                transactionsTableHeader()

                ForEach(store.state.filtered(calendar: calendar)) { transaction in
                    transactionRow(transaction)
                }
            }
        }
    }

    private var headerPeriodMenu: some View {
        headerFilterPopoverCard(
            caption: "Período",
            value: store.periodFilter.name,
            icon: "calendar",
            filter: .period
        ) {
            ForEach(TransactionPeriodFilter.allCases) { filter in
                headerFilterOption(filter.name) {
                    store.send(.periodFilterSelected(filter))
                }
            }
        }
    }

    private var headerKindMenu: some View {
        headerFilterPopoverCard(
            caption: "Tipo",
            value: store.kindFilter.name,
            icon: "arrow.left.arrow.right.circle",
            filter: .kind
        ) {
            ForEach(TransactionKindFilter.allCases) { filter in
                headerFilterOption(filter.name) {
                    store.send(.kindFilterSelected(filter))
                }
            }
        }
    }

    private var headerBankMenu: some View {
        headerFilterPopoverCard(
            caption: "Banco",
            value: store.bankFilterName,
            icon: AppIcon.sidebarAccounts.systemImage,
            filter: .bank
        ) {
            headerFilterOption("Todos bancos") {
                store.send(.bankFilterSelected(.all))
            }
            Divider()
            ForEach(store.availableBanks) { institution in
                headerFilterOption(institution.name) {
                    store.send(.bankFilterSelected(.bank(institution.id)))
                }
            }
        }
    }

    private var headerCategoryMenu: some View {
        headerFilterPopoverCard(
            caption: "Categoria",
            value: store.categoryFilterName,
            icon: "tag",
            filter: .category
        ) {
            headerFilterOption("Todas categorias") {
                store.send(.categoryFilterSelected(.all))
            }
            Divider()
            ForEach(store.sortedRootCategories) { category in
                headerFilterOption(category.name) {
                    store.send(.categoryFilterSelected(.category(category.id)))
                }
            }
        }
    }

    private func transactionsTableCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(spacing: GranaTheme.Spacing.none) {
                content()
            }
        }
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.panel)
        .clipShape(RoundedRectangle(cornerRadius: GranaTheme.Radius.panel, style: .continuous))
    }

    private func transactionsTableHeader() -> some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            Text("Banco")
                .frame(width: 60, alignment: .center)
            Text("Data")
                .frame(width: 92, alignment: .leading)
            Text("Descrição")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Categoria")
                .frame(width: 160, alignment: .leading)
            Text("Valor")
                .frame(width: 132, alignment: .trailing)
            Text("Ações")
                .frame(width: 76, alignment: .center)
        }
        .font(GranaTheme.Typography.footnoteEmphasis)
        .foregroundStyle(.secondary)
        .padding(.horizontal, GranaTheme.Spacing.md)
        .frame(minHeight: 44)
        .background(GranaTheme.Palette.paper.opacity(0.55))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GranaTheme.Palette.line)
                .frame(height: 1)
        }
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            bankCell(transaction)

            Text(transaction.occurredAt.formatted(date: .numeric, time: .omitted))
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            descriptionCell(transaction)
                .frame(maxWidth: .infinity, alignment: .leading)

            categoryCell(transaction)
                .frame(width: 160, alignment: .leading)

            accountingAmount(transaction.amount)
                .foregroundStyle(amountColor(for: transaction))
                .frame(width: 132, alignment: .trailing)

            rowActions(transaction)
                .frame(width: 76)
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .frame(minHeight: 54)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GranaTheme.Palette.line)
                .frame(height: 1)
        }
    }

    private func headerFilterPopoverCard<Content: View>(
        caption: String,
        value: String,
        icon: String,
        filter: TransactionsHeaderPresentedFilter,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Button {
            store.send(.headerFilterPresented(filter))
        } label: {
            headerFilterCard(caption: caption, value: value, icon: icon)
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: Binding(
                get: { store.presentedHeaderFilter == filter },
                set: { isPresented in
                    if !isPresented, store.presentedHeaderFilter == filter {
                        store.send(.headerFilterPresented(nil))
                    }
                }
            ),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.none) {
                    content()
                }
                .padding(GranaTheme.Spacing.xs)
            }
            .frame(minWidth: 220, maxHeight: 320)
            .background(GranaTheme.Palette.paperSolid)
        }
    }

    private func headerFilterOption(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(GranaTheme.Typography.footnoteEmphasis)
                .foregroundStyle(GranaTheme.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GranaTheme.Spacing.sm)
                .padding(.vertical, GranaTheme.Spacing.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func headerFilterCard(
        caption: String,
        value: String,
        icon: String
    ) -> some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(GranaTheme.Palette.tealDeep)

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                Text(caption)
                    .font(GranaTheme.Typography.caption2Emphasis)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(GranaTheme.Typography.footnoteEmphasis)
                    .lineLimit(1)
            }

            Spacer(minLength: GranaTheme.Spacing.xs)

            Image(systemName: "chevron.down")
                .font(.system(size: GranaTheme.IconSize.micro, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .frame(minWidth: 168, minHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GranaTheme.Palette.paper.opacity(0.84))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GranaTheme.Palette.line, lineWidth: 1)
        }
    }

    private func descriptionCell(_ transaction: Transaction) -> some View {
        Text(transaction.description)
            .font(GranaTheme.Typography.subheadlineEmphasis)
            .lineLimit(1)
    }

    private func categoryCell(_ transaction: Transaction) -> some View {
        HStack(spacing: GranaTheme.Spacing.xs) {
            CategoryBadge(
                category: store.state.category(for: transaction.categoryId),
                icon: store.state.icon(for: transaction.categoryId),
                iconOnly: true
            )
            Text(store.state.subcategoryName(for: transaction) ?? store.state.categoryName(for: transaction))
                .font(GranaTheme.Typography.footnoteEmphasis)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func bankCell(_ transaction: Transaction) -> some View {
        InstitutionIcon(kind: store.state.institutionKind(for: transaction), size: 22)
            .frame(width: 60, alignment: .center)
            .help(store.state.accountName(for: transaction))
    }

    private func rowActions(_ transaction: Transaction) -> some View {
        let canMutate = store.state.supportsBasicMutation(for: transaction)
        let unsupportedMessage = "A edição desta transação não está disponível nesta configuração."

        return HStack(spacing: GranaTheme.Spacing.sm) {
            Button {
                store.send(.editButtonTapped(transaction))
            } label: {
                Image(systemName: AppIcon.edit.systemImage)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!canMutate)
            .help(canMutate ? "Editar" : unsupportedMessage)

            Button(role: .destructive) {
                store.send(.deleteButtonTapped(transaction))
            } label: {
                Image(systemName: AppIcon.delete.systemImage)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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

private struct TransactionsHeaderView: View {
    @Binding var searchText: String
    let countText: String
    let onImport, onAdd: () -> Void
    let bankControl, periodControl, categoryControl, kindControl: AnyView

    var body: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                        HStack(spacing: GranaTheme.Spacing.sm) {
                            Text("Transações")
                                .font(GranaTheme.Typography.title3)
                        }
                        Text(countText)
                            .font(GranaTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: GranaTheme.Spacing.none)
                    searchBox
                        .frame(width: 520)
                }
                HStack(spacing: GranaTheme.Spacing.sm) {
                    bankControl
                    categoryControl
                    periodControl
                    kindControl
                    Spacer(minLength: GranaTheme.Spacing.none)
                }
            }
            .padding(GranaTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.panel)

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                actionsCard
            }
            .frame(width: 288)
        }
    }

    private var searchBox: some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(GranaTheme.Palette.teal.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.tealDeep)
            }
            TextField("Descrição, categoria ou conta", text: $searchText)
                .textFieldStyle(.plain)
                .font(GranaTheme.Typography.subheadlineEmphasis)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .padding(.vertical, GranaTheme.Spacing.sm)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GranaTheme.Palette.paper.opacity(0.92))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GranaTheme.Palette.line, lineWidth: 1)
        }
    }

    private var actionsCard: some View {
        VStack(spacing: GranaTheme.Spacing.xs) {
            action("Adicionar", AppIcon.add.systemImage, onAdd, true)
            action("Importar", AppIcon.importFile.systemImage, onImport, false)
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.panel)
    }

    @ViewBuilder private func action(
        _ title: String,
        _ icon: String,
        _ run: @escaping () -> Void,
        _ primary: Bool
    ) -> some View {
        if primary {
            Button(action: run) {
                Label(title, systemImage: icon)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
        } else {
            Button(action: run) {
                Label(title, systemImage: icon)
            }
            .buttonStyle(GranaSecondaryButtonStyle())
        }
    }
}
