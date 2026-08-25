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
        VStack(spacing: 0) {
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
                .padding(.vertical, 10)
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
        VStack(spacing: 12) {
            transactionsHeader(store: store)
            transactionsContentSection(store: store)
        }
        .granaPagePadding()
    }

    private func transactionsHeader(store: TransactionStore) -> some View {
        HStack(alignment: .top, spacing: 12) {
            tableControlsCard(store: store)
                .frame(maxWidth: .infinity, alignment: .leading)
            actionCard
                .frame(width: 290)
        }
    }

    private func tableControlsCard(store: TransactionStore) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(transactionsCountText(store: store))
                    .font(GranaTheme.Typography.subheadlineEmphasis)
                    .foregroundStyle(GranaTheme.Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 16)
                searchField
                    .frame(maxWidth: 390, alignment: .trailing)
            }

            HStack(spacing: 10) {
                bankMenu(store: store)
                periodMenu
                categoryMenu(store: store)
                kindMenu
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }

    private var actionCard: some View {
        HStack(spacing: 10) {
            importActionButton
            addActionButton
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }

    private func transactionsContentSection(store: TransactionStore) -> some View {
        VStack(spacing: 12) {
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

    private var periodMenu: some View {
        filterMenu(title: periodFilter.name, icon: "calendar") {
            ForEach(TransactionPeriodFilter.allCases) { filter in
                Button(filter.name) {
                    periodFilter = filter
                }
            }
        }
    }

    private func bankMenu(store: TransactionStore) -> some View {
        filterMenu(
            title: bankFilter.name(store: store),
            icon: AppIcon.sidebarAccounts.systemImage
        ) {
            Button("Todos bancos") {
                bankFilter = .all
            }
            Divider()
            ForEach(availableBanks(store: store)) { institution in
                Button(institution.name) {
                    bankFilter = .bank(institution.id)
                }
            }
        }
    }

    private var importActionButton: some View {
        Button {
            showingImport = true
        } label: {
            Label("Importar", systemImage: AppIcon.importFile.systemImage)
        }
        .buttonStyle(GranaSecondaryButtonStyle())
    }

    private var addActionButton: some View {
        Button {
            showingForm = true
        } label: {
            Label("Adicionar", systemImage: AppIcon.add.systemImage)
        }
        .buttonStyle(GranaPrimaryButtonStyle())
    }

    private var kindMenu: some View {
        filterMenu(title: kindFilter.name, icon: "arrow.left.arrow.right.circle") {
            ForEach(TransactionKindFilter.allCases) { filter in
                Button(filter.name) {
                    kindFilter = filter
                }
            }
        }
    }

    private func categoryMenu(store: TransactionStore) -> some View {
        filterMenu(title: categoryFilter.name(store: store), icon: "tag") {
            Button("Todas categorias") {
                categoryFilter = .all
            }
            Divider()
            ForEach(rootCategories(store: store)) { category in
                Button(category.name) {
                    categoryFilter = .category(category.id)
                }
            }
        }
    }

    private func transactionsTableCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                content()
            }
        }
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.panel)
        .clipShape(RoundedRectangle(cornerRadius: GranaTheme.Radius.panel, style: .continuous))
    }

    private func transactionsTableHeader() -> some View {
        HStack(spacing: 12) {
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
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background(GranaTheme.Palette.paper.opacity(0.55))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GranaTheme.Palette.line)
                .frame(height: 1)
        }
    }

    private func transactionRow(_ transaction: Transaction, store: TransactionStore) -> some View {
        HStack(spacing: 12) {
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
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GranaTheme.Palette.line)
                .frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Buscar descrição ou categoria", text: $searchText)
                .textFieldStyle(.plain)

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
        .padding(.horizontal, 14)
        .frame(width: 360)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(GranaTheme.Palette.paper.opacity(0.9))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(GranaTheme.Palette.line, lineWidth: 1)
        }
    }

    private func filterMenu<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: GranaTheme.IconSize.micro, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .font(GranaTheme.Typography.subheadlineEmphasis)
            .foregroundStyle(GranaTheme.Palette.ink)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(GranaTheme.Palette.paper.opacity(0.82))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(GranaTheme.Palette.line, lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
    }

    private func descriptionCell(_ transaction: Transaction) -> some View {
        Text(transaction.description)
            .font(GranaTheme.Typography.subheadlineEmphasis)
            .lineLimit(1)
    }

    private func categoryCell(_ transaction: Transaction, store: TransactionStore) -> some View {
        HStack(spacing: 8) {
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

        return HStack(spacing: 12) {
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
        return HStack(spacing: 4) {
            Text("R$")
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
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
        let visible = filtered(store: store).count
        let total = store.transactions.count
        if visible == total {
            return "\(visible) transações"
        }
        return "\(visible) de \(total) transações"
    }

    private func rootCategories(store: TransactionStore) -> [Category] {
        store.categories
            .filter { $0.parentId == nil }
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private func availableBanks(store: TransactionStore) -> [Institution] {
        let institutionIds = Set(store.accounts.compactMap(\.institutionId))
        return store.institutions
            .filter { institutionIds.contains($0.id) }
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }
}

private enum TransactionKindFilter: CaseIterable, Identifiable {
    case all
    case expense
    case income
    case transfer

    var id: Self {
        self
    }

    var name: String {
        switch self {
        case .all: "Todas"
        case .expense: "Despesas"
        case .income: "Receitas"
        case .transfer: "Transferências"
        }
    }

    func matches(_ transaction: Transaction, store: TransactionStore) -> Bool {
        let kind = store.category(for: transaction.categoryId)?.kind
        switch self {
        case .all:
            return true
        case .expense:
            return kind == .expense
        case .income:
            return kind == .income
        case .transfer:
            return kind == .transfer
        }
    }
}

private enum TransactionCategoryFilter: Equatable {
    case all
    case category(UUID)

    func name(store: TransactionStore) -> String {
        switch self {
        case .all:
            return "Todas categorias"
        case let .category(id):
            return store.category(for: id)?.name ?? "Categoria"
        }
    }

    func matches(_ transaction: Transaction, store _: TransactionStore) -> Bool {
        switch self {
        case .all:
            return true
        case let .category(id):
            return transaction.categoryId == id || transaction.subcategoryId == id
        }
    }
}

private enum TransactionPeriodFilter: CaseIterable, Identifiable {
    case month
    case quarter
    case year
    case all

    var id: Self {
        self
    }

    var name: String {
        switch self {
        case .month: "Este mês"
        case .quarter: "90 dias"
        case .year: "Este ano"
        case .all: "Tudo"
        }
    }

    func matches(_ transaction: Transaction, calendar: Calendar = .current, today: Date = Date()) -> Bool {
        switch self {
        case .all:
            return true
        case .month:
            let interval = calendar.dateInterval(of: .month, for: today)
            return interval?.contains(transaction.occurredAt) ?? true
        case .year:
            let interval = calendar.dateInterval(of: .year, for: today)
            return interval?.contains(transaction.occurredAt) ?? true
        case .quarter:
            guard let start = calendar.date(byAdding: .day, value: -90, to: today) else {
                return true
            }
            return transaction.occurredAt >= start && transaction.occurredAt <= today
        }
    }
}

private enum TransactionBankFilter: Equatable {
    case all

    case bank(UUID)

    func name(store: TransactionStore) -> String {
        switch self {
        case .all:
            return "Todos bancos"
        case let .bank(id):
            return store.institution(for: id)?.name ?? "Banco"
        }
    }

    func matches(_ transaction: Transaction, store: TransactionStore) -> Bool {
        switch self {
        case .all:
            return true
        case let .bank(id):
            return store.account(for: transaction.accountId)?.institutionId == id
        }
    }
}
