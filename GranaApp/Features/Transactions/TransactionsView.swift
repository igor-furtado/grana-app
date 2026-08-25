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
    @State private var periodFilter: TransactionPeriodFilter = .month
    @State private var accountFilter: TransactionAccountFilter = .all

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
            contentBody(store: store)
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
        .navigationTitle("Transações")
        .toolbar { toolbarContent(store: store) }
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

    private func contentBody(store: TransactionStore) -> some View {
        VStack(spacing: 12) {
            transactionsTableCard {
                transactionsTableHeader()

                ForEach(filtered(store: store)) { transaction in
                    transactionRow(transaction, store: store)
                }
            }
        }
        .granaPagePadding()
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

    @ToolbarContentBuilder
    private func toolbarContent(store _: TransactionStore) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 12) {
                accountMenu
                periodMenu
                Spacer(minLength: 12)
                kindFilterPicker
                searchField
                importButton
                addButton
            }
            .frame(minWidth: 920)
        }
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

    private var accountMenu: some View {
        filterMenu(
            title: accountFilter.name,
            icon: AppIcon.sidebarAccounts.systemImage
        ) {
            ForEach(TransactionAccountFilter.allCases) { filter in
                Button(filter.name) {
                    accountFilter = filter
                }
            }
        }
    }

    private var importButton: some View {
        Button {
            showingImport = true
        } label: {
            Label("Importar", systemImage: AppIcon.importFile.systemImage)
        }
        .buttonStyle(ToolbarSurfaceButtonStyle())
    }

    private var addButton: some View {
        Button {
            showingForm = true
        } label: {
            Label("Adicionar", systemImage: AppIcon.add.systemImage)
        }
        .buttonStyle(ToolbarSurfaceButtonStyle(primary: true))
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
        .font(.system(size: 12, weight: .bold))
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
                .font(GranaTheme.Typography.number(size: 11, weight: .regular))
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
        .frame(width: 280)
        .frame(minHeight: 42)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
    }

    private var kindFilterPicker: some View {
        HStack(spacing: 6) {
            ForEach(TransactionKindFilter.allCases) { filter in
                Button(filter.name) {
                    kindFilter = filter
                }
                .buttonStyle(FilterPillButtonStyle(isSelected: kindFilter == filter))
            }
        }
        .padding(6)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
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
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(GranaTheme.Palette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
        }
        .menuStyle(.borderlessButton)
    }

    private func descriptionCell(_ transaction: Transaction) -> some View {
        Text(transaction.description)
            .font(.system(size: 13, weight: .semibold))
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
                .font(.system(size: 12, weight: .semibold))
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

    /// Renderiza o valor no estilo "contábil": símbolo da moeda colado à
    /// esquerda da célula, número colado à direita, espaço flexível no meio.
    /// É o layout que o Excel chama de "Accounting" — facilita escanear
    /// colunas verticais de valores.
    private func accountingAmount(_ amount: Decimal) -> some View {
        let number = amount.formatted(
            .number
                .precision(.fractionLength(2))
                .locale(Self.ptBR)
        )
        return HStack(spacing: 4) {
            // Símbolo da moeda fica em `.secondary` (mesmo tom da data) pra
            // não competir com o número, que recebe a cor do `CategoryKind`
            // via `.foregroundStyle(amountColor(...))` aplicado por fora.
            Text("R$")
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(number)
        }
        .font(GranaTheme.Typography.number(size: 13, weight: .regular))
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
            if !accountFilter.matches(transaction, store: store) {
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

private enum TransactionAccountFilter: CaseIterable, Identifiable {
    case all
    case checking
    case creditCard

    var id: Self {
        self
    }

    var name: String {
        switch self {
        case .all: "Todas contas"
        case .checking: "Contas correntes"
        case .creditCard: "Cartões"
        }
    }

    func matches(_ transaction: Transaction, store: TransactionStore) -> Bool {
        guard let account = store.account(for: transaction.accountId) else {
            return self == .all
        }

        switch self {
        case .all:
            return true
        case .checking:
            return account.type == .checking
        case .creditCard:
            return account.type == .creditCard
        }
    }
}

private struct FilterPillButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(isSelected ? GranaTheme.Palette.creamText : GranaTheme.Palette.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background(
                isSelected
                    ? AnyShapeStyle(GranaTheme.brandGradient(pressed: configuration.isPressed))
                    : AnyShapeStyle(
                        configuration.isPressed
                            ? GranaTheme.Palette.ink.opacity(0.08)
                            : Color.clear
                    ),
                in: Capsule(style: .continuous)
            )
    }
}

private struct ToolbarSurfaceButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(primary ? GranaTheme.Palette.creamText : GranaTheme.Palette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .background(
                backgroundStyle(pressed: configuration.isPressed),
                in: RoundedRectangle(
                    cornerRadius: GranaTheme.Radius.control,
                    style: .continuous
                )
            )
    }

    private func backgroundStyle(pressed: Bool) -> some ShapeStyle {
        if primary {
            return AnyShapeStyle(GranaTheme.brandGradient(pressed: pressed))
        }
        return AnyShapeStyle(
            pressed
                ? GranaTheme.Palette.ink.opacity(0.10)
                : GranaTheme.Palette.soft
        )
    }
}
