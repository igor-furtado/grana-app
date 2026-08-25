import SwiftUI

struct TransactionsView: View {
    private static let ptBR = Locale(identifier: "pt_BR")

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.calendar) private var calendar
    @State private var store: TransactionStore?
    @State private var showingForm = false
    @State private var showingImport = false
    @State private var editing: Transaction?
    @State private var pendingDelete: Transaction?
    @State private var searchText = ""
    @State private var kindFilter: TransactionKindFilter = .all
    @State private var categoryFilter: TransactionCategoryFilter = .all
    @State private var periodFilter: TransactionPeriodFilter = .month
    @State private var bankFilter: TransactionBankFilter = .all
    @State private var presentedHeaderFilter: TransactionsHeaderPresentedFilter?

    var body: some View {
        Group {
            if let store {
                content(store: store)
                    .environment(store)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if store == nil {
                store = TransactionStore(container: environment.container)
            }
        }
    }

    private func content(store: TransactionStore) -> some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            mainContent(store: store)
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
                            Task { await store.loadMoreTransactions() }
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, GranaTheme.Spacing.sm)
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
        .sheet(isPresented: $showingForm) {
            TransactionFormView()
                .environment(store)
        }
        .sheet(item: $editing) { transaction in
            TransactionFormView(existing: transaction)
                .environment(store)
        }
        .sheet(isPresented: $showingImport) {
            ImportView()
                .environment(environment)
        }
        .confirmationDialog(
            "Apagar transação?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { transaction in
            Button("Apagar", role: .destructive) {
                Task {
                    do {
                        try await store.delete(id: transaction.id)
                    } catch {
                        NoticeCenter.shared.report(error)
                    }
                    pendingDelete = nil
                }
            }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: { transaction in
            Text(deletePreview(for: transaction, store: store))
        }
        .task {
            await store.load()
        }
    }

    private func mainContent(store: TransactionStore) -> some View {
        contentBody(store: store)
    }

    private func contentBody(store: TransactionStore) -> some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            transactionsHeader(store: store)
            transactionsContentSection(store: store)
        }
        .granaPagePadding()
    }

    private func transactionsHeader(store: TransactionStore) -> some View {
        TransactionsHeaderView(
            searchText: $searchText,
            countText: transactionsCountText(store: store),
            onImport: { showingImport = true },
            onAdd: { showingForm = true },
            bankControl: AnyView(headerBankMenu(store: store)),
            periodControl: AnyView(headerPeriodMenu),
            categoryControl: AnyView(headerCategoryMenu(store: store)),
            kindControl: AnyView(headerKindMenu)
        )
    }

    private func transactionsContentSection(store: TransactionStore) -> some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            transactionsTableCard {
                transactionsTableHeader()

                ForEach(filtered(store: store)) { transaction in
                    transactionRow(transaction, store: store)
                }
            }
        }
    }

    private func deletePreview(
        for transaction: Transaction,
        store: TransactionStore
    ) -> String {
        var message = "\(transaction.description) — \(transaction.amount.formatted(.currency(code: "BRL")))"
        let affectsCard = store.account(for: transaction.accountId)?.type == .creditCard
            || transaction.destinationAccountId.flatMap(store.account(for:))?.type == .creditCard
        if affectsCard {
            message += "\n\nFaturas, créditos, pagamentos e quitações posteriores serão recalculados antes da exclusão."
        }
        let linkedRefundCount = store.transactions.filter {
            $0.refundOfTransactionId == transaction.id
        }.count
        if linkedRefundCount > 0 {
            message += "\nA exclusão será rejeitada enquanto houver \(linkedRefundCount) estorno(s) vinculado(s)."
        }
        return message
    }

    private var headerPeriodMenu: some View {
        headerFilterPopoverCard(
            caption: "Período",
            value: periodFilter.name,
            icon: "calendar",
            filter: .period
        ) {
            ForEach(TransactionPeriodFilter.allCases) { filter in
                headerFilterOption(filter.name) {
                    periodFilter = filter
                    presentedHeaderFilter = nil
                }
            }
        }
    }

    private var headerKindMenu: some View {
        headerFilterPopoverCard(
            caption: "Tipo",
            value: kindFilter.name,
            icon: "arrow.left.arrow.right.circle",
            filter: .kind
        ) {
            ForEach(TransactionKindFilter.allCases) { filter in
                headerFilterOption(filter.name) {
                    kindFilter = filter
                    presentedHeaderFilter = nil
                }
            }
        }
    }

    private func headerBankMenu(store: TransactionStore) -> some View {
        headerFilterPopoverCard(
            caption: "Banco",
            value: bankFilter.name(store: store),
            icon: AppIcon.sidebarAccounts.systemImage,
            filter: .bank
        ) {
            headerFilterOption("Todos bancos") {
                bankFilter = .all
                presentedHeaderFilter = nil
            }
            Divider()
            ForEach(availableBanks(store: store)) { institution in
                headerFilterOption(institution.name) {
                    bankFilter = .bank(institution.id)
                    presentedHeaderFilter = nil
                }
            }
        }
    }

    private func headerCategoryMenu(store: TransactionStore) -> some View {
        headerFilterPopoverCard(
            caption: "Categoria",
            value: categoryFilter.name(store: store),
            icon: "tag",
            filter: .category
        ) {
            headerFilterOption("Todas categorias") {
                categoryFilter = .all
                presentedHeaderFilter = nil
            }
            Divider()
            ForEach(rootCategories(store: store)) { category in
                headerFilterOption(category.name) {
                    categoryFilter = .category(category.id)
                    presentedHeaderFilter = nil
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

    private func transactionRow(_ transaction: Transaction, store: TransactionStore) -> some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            bankCell(transaction, store: store)

            Text(transaction.occurredAt.formatted(date: .numeric, time: .omitted))
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            descriptionCell(transaction)
                .frame(maxWidth: .infinity, alignment: .leading)

            categoryCell(transaction, store: store)
                .frame(width: 160, alignment: .leading)

            accountingAmount(transaction.amount)
                .foregroundStyle(amountColor(for: transaction, store: store))
                .frame(width: 132, alignment: .trailing)

            rowActions(transaction, store: store)
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
            presentedHeaderFilter = filter
        } label: {
            headerFilterCard(caption: caption, value: value, icon: icon)
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: Binding(
                get: { presentedHeaderFilter == filter },
                set: { isPresented in
                    if !isPresented, presentedHeaderFilter == filter {
                        presentedHeaderFilter = nil
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

    private func categoryCell(_ transaction: Transaction, store: TransactionStore) -> some View {
        HStack(spacing: GranaTheme.Spacing.xs) {
            CategoryBadge(
                category: store.category(for: transaction.categoryId),
                icon: store.icon(for: transaction.categoryId),
                iconOnly: true
            )
            Text(subcategoryName(for: transaction, store: store) ?? categoryName(for: transaction, store: store))
                .font(GranaTheme.Typography.footnoteEmphasis)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func bankCell(_ transaction: Transaction, store: TransactionStore) -> some View {
        InstitutionIcon(kind: institutionKind(for: transaction, store: store), size: 22)
            .frame(width: 60, alignment: .center)
            .help(accountName(for: transaction, store: store))
    }

    private func rowActions(_ transaction: Transaction, store: TransactionStore) -> some View {
        let canMutate = store.supportsBasicMutation(for: transaction)
        let unsupportedMessage = "A edição desta transação não está disponível nesta configuração."

        return HStack(spacing: GranaTheme.Spacing.sm) {
            Button {
                editing = transaction
            } label: {
                Image(systemName: AppIcon.edit.systemImage)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!canMutate)
            .help(canMutate ? "Editar" : unsupportedMessage)

            Button(role: .destructive) {
                pendingDelete = transaction
            } label: {
                Image(systemName: AppIcon.delete.systemImage)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!canMutate)
            .help(canMutate ? "Apagar" : unsupportedMessage)
        }
    }

    private func institutionKind(
        for transaction: Transaction,
        store: TransactionStore
    ) -> InstitutionKind {
        guard let account = store.account(for: transaction.accountId),
              let institutionId = account.institutionId,
              let institution = store.institution(for: institutionId)
        else {
            return .other
        }
        return institution.kind
    }

    private func subcategoryName(for transaction: Transaction, store: TransactionStore) -> String? {
        guard let subcategoryId = transaction.subcategoryId else { return nil }
        return store.category(for: subcategoryId)?.name
    }

    private func categorySummary(for transaction: Transaction, store: TransactionStore) -> String {
        let category = categoryName(for: transaction, store: store)
        guard let subcategory = subcategoryName(for: transaction, store: store) else {
            return category
        }
        return "\(category) · \(subcategory)"
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

    private func amountColor(for transaction: Transaction, store: TransactionStore) -> Color {
        switch store.category(for: transaction.categoryId)?.kind {
        case .income: return .income
        case .transfer: return .transfer
        case .expense: return .expense
        case .none: return .primary
        }
    }

    private func accountName(for transaction: Transaction, store: TransactionStore) -> String {
        store.account(for: transaction.accountId).map { store.displayName(for: $0) } ?? "-"
    }

    private func categoryName(for transaction: Transaction, store: TransactionStore) -> String {
        store.category(for: transaction.categoryId)?.name ?? "-"
    }

    private func filtered(store: TransactionStore) -> [Transaction] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let needle = trimmed.lowercased()
        return store.transactions.filter { transaction in
            if !kindFilter.matches(transaction, store: store) {
                return false
            }
            if !periodFilter.matches(transaction, calendar: calendar) {
                return false
            }
            if !bankFilter.matches(transaction, store: store) {
                return false
            }
            if !categoryFilter.matches(transaction, store: store) {
                return false
            }
            guard !needle.isEmpty else { return true }
            if transaction.description.lowercased().contains(needle) { return true }
            if categorySummary(for: transaction, store: store).lowercased().contains(needle) {
                return true
            }
            if accountName(for: transaction, store: store).lowercased().contains(needle) {
                return true
            }
            return false
        }
    }

    private func transactionsCountText(store: TransactionStore) -> String {
        let visible = filtered(store: store).count, total = store.transactions.count
        return visible == total ? "\(visible) transações" : "\(visible) de \(total) transações"
    }

    private func rootCategories(store: TransactionStore) -> [Category] {
        store.categories.filter { $0.parentId == nil }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func availableBanks(store: TransactionStore) -> [Institution] {
        let ids = Set(store.accounts.compactMap(\.institutionId))
        return store.institutions.filter { ids.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

private enum TransactionsHeaderPresentedFilter {
    case bank
    case category
    case period
    case kind
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

private enum TransactionKindFilter: CaseIterable, Identifiable {
    case all, expense, income, transfer
    var id: Self {
        self
    }

    var name: String {
        self == .all ? "Todas" : self == .expense ? "Despesas" : self == .income ? "Receitas" : "Transferências"
    }

    func matches(_ transaction: Transaction, store: TransactionStore) -> Bool {
        let kind = store.category(for: transaction.categoryId)?.kind
        return self == .all || self == .expense && kind == .expense || self == .income && kind == .income || self ==
            .transfer && kind == .transfer
    }
}

private enum TransactionCategoryFilter: Equatable {
    case all, category(UUID)

    func name(store: TransactionStore) -> String {
        if case let .category(id) = self {
            return store.category(for: id)?.name ?? "Categoria"
        }
        return "Todas categorias"
    }

    func matches(
        _ transaction: Transaction,
        store _: TransactionStore
    ) -> Bool {
        if case let .category(id) = self {
            return transaction.categoryId == id || transaction.subcategoryId == id
        }
        return true
    }
}

private enum TransactionPeriodFilter: CaseIterable, Identifiable {
    case month, quarter, year, all
    var id: Self {
        self
    }

    var name: String {
        self == .month ? "Este mês" : self == .quarter ? "90 dias" : self == .year ? "Este ano" : "Tudo"
    }

    func matches(_ transaction: Transaction, calendar: Calendar = .current, today: Date = Date()) -> Bool {
        if self == .all { return true }
        if self ==
            .month { return calendar.dateInterval(of: .month, for: today)?.contains(transaction.occurredAt) ?? true }
        if self ==
            .year { return calendar.dateInterval(of: .year, for: today)?.contains(transaction.occurredAt) ?? true }
        guard let start = calendar.date(byAdding: .day, value: -90, to: today) else { return true }
        return transaction.occurredAt >= start && transaction.occurredAt <= today
    }
}

private enum TransactionBankFilter: Equatable {
    case all, bank(UUID)

    func name(store: TransactionStore) -> String {
        if case let .bank(id) = self {
            return store.institution(for: id)?.name ?? "Banco"
        }
        return "Todos bancos"
    }

    func matches(
        _ transaction: Transaction,
        store: TransactionStore
    ) -> Bool {
        if case let .bank(id) = self {
            return store.account(for: transaction.accountId)?.institutionId == id
        }
        return true
    }
}
