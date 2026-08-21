import Foundation
import Observation
import OSLog

/// Estado observável da feature Transações.
///
/// **Por que `@MainActor` na classe inteira:** SwiftUI exige que mutações em
/// estado observado pela UI aconteçam na main thread. Anotar a classe com
/// `@MainActor` força isso em tempo de compilação — qualquer chamada de fora
/// da main thread vira `await store.foo()` e o compilador checa. Vai bem
/// junto da configuração `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` do
/// target, mas explícito ajuda legibilidade.
///
/// **Por que juntar transactions/accounts/categories no mesmo store:** a UI
/// de Transação precisa dos três pra renderizar (lista mostra nome de
/// categoria, formulário mostra picker de account). Manter em stores
/// separados forçaria a View a observar três objetos e re-renderizar três
/// vezes em ações cruzadas — overhead sem benefício na Fase 1.
@MainActor
@Observable
final class TransactionStore {
    private let container: AppContainer
    private let pageSize = 50
    private var nextCursor: TransactionRemotePageCursor?

    private(set) var transactions: [Transaction] = []
    private(set) var accounts: [Account] = []
    /// Necessário pra derivar `displayName(for:)` da conta (que precisa do
    /// nome do banco como prefixo). Catálogo pequeno e estático, então vale
    /// carregar junto do restante do snapshot da tela.
    private(set) var institutions: [Institution] = []
    /// A partir da Fase 4.6 o sufixo do display name (número da conta /
    /// ••••last4) vive nas tabelas-irmãs `bank_accounts` e `credit_cards`.
    /// Esses detalhes entram no mesmo refresh para evitar lookups extras na UI.
    private(set) var bankDetails: [BankAccountDetails] = []
    private(set) var creditCards: [CreditCardDetails] = []
    private(set) var categories: [Category] = []
    private(set) var statements: [Statement] = []
    private(set) var statementPayments: [StatementPayment] = []
    private(set) var isLoading = false
    private(set) var isLoadingMoreTransactions = false
    private(set) var hasMoreTransactions = false
    var lastError: Error?
    let supportsAdvancedCardRules = false

    init(container: AppContainer) {
        self.container = container
    }

    // MARK: - Loading

    func load() async {
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await refreshSnapshot()
        } catch {
            handleRefreshFailure(error)
        }
    }

    func loadMoreTransactions() async {
        guard let nextCursor, !isLoadingMoreTransactions else { return }

        isLoadingMoreTransactions = true
        defer { isLoadingMoreTransactions = false }

        do {
            let page = try await container.remoteTransactions.loadPage(
                cursor: nextCursor,
                limit: pageSize
            )
            transactions.append(contentsOf: page.transactions)
            self.nextCursor = page.nextCursor
            hasMoreTransactions = page.nextCursor != nil
            lastError = nil
        } catch {
            lastError = error
            NoticeCenter.shared.report(error)
        }
    }

    // MARK: - Mutations

    /// Cria uma transação nova. A UI só passa os campos do formulário;
    /// o store preenche id, createdAt e updatedAt.
    ///
    func add(
        accountId: UUID,
        categoryId: UUID,
        subcategoryId: UUID?,
        amount: Decimal,
        occurredAt: Date,
        description: String,
        notes: String?,
        destinationAccountId: UUID? = nil,
        refundOfTransactionId: UUID? = nil
    ) async throws {
        let input = TransactionMutationInput(
            accountId: accountId,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            amount: amount,
            occurredAt: occurredAt,
            description: description,
            notes: notes,
            destinationAccountId: destinationAccountId,
            refundOfTransactionId: refundOfTransactionId
        )
        try await container.remoteTransactions.create(input: input)
        try await refreshAfterMutation()
    }

    func update(_ transaction: Transaction) async throws {
        let input = TransactionMutationInput(
            accountId: transaction.accountId,
            categoryId: transaction.categoryId,
            subcategoryId: transaction.subcategoryId,
            amount: transaction.amount,
            occurredAt: transaction.occurredAt,
            description: transaction.description,
            notes: transaction.notes,
            destinationAccountId: transaction.destinationAccountId,
            refundOfTransactionId: transaction.refundOfTransactionId
        )
        try await container.remoteTransactions.update(
            transactionId: transaction.id,
            input: input
        )
        try await refreshAfterMutation()
    }

    func delete(id: UUID) async throws {
        try await container.remoteTransactions.delete(transactionId: id)
        try await refreshAfterMutation()
    }

    // MARK: - Helpers para a UI

    func category(for id: UUID) -> Category? {
        categories.first { $0.id == id }
    }

    /// Ícone "efetivo" da categoria. Se a categoria for raiz, retorna o ícone
    /// dela (resolvido via slug). Se for subcategoria, retorna o ícone do pai
    /// (porque por design só raízes têm slug — ver `Category.icon`).
    func icon(for categoryId: UUID) -> CategoryIcon? {
        guard let cat = category(for: categoryId) else { return nil }
        if let icon = cat.icon { return icon }
        if let parentId = cat.parentId,
           let parent = category(for: parentId)
        {
            return parent.icon
        }
        return nil
    }

    func account(for id: UUID) -> Account? {
        accounts.first { $0.id == id }
    }

    func supportsBasicMutation(for transaction: Transaction) -> Bool {
        if transaction.statementId != nil || transaction.refundOfTransactionId != nil {
            return false
        }

        if account(for: transaction.accountId)?.type == .creditCard {
            return false
        }

        if let destinationAccountId = transaction.destinationAccountId,
           account(for: destinationAccountId)?.type == .creditCard
        {
            return false
        }

        return true
    }

    // MARK: - Statement helpers (Fase 4.7)

    /// Statement à qual a transação pertence (compra de cartão). `nil` pra
    /// transações em conta corrente ou transferências.
    func statement(for transaction: Transaction) -> Statement? {
        guard let id = transaction.statementId else { return nil }
        return statements.first { $0.id == id }
    }

    /// Statements em aberto de uma conta-cartão, ordenadas por `closing_date`
    /// crescente (mais antiga primeiro). Usada pelo picker de pagamento.
    func openStatements(for accountId: UUID) -> [Statement] {
        statements
            .filter { $0.accountId == accountId && $0.remainingAmount > 0 }
            .sorted { $0.closingDate < $1.closingDate }
    }

    func refundablePurchases(
        accountId: UUID?,
        occurredAt: Date,
        excluding transactionId: UUID? = nil
    ) -> [Transaction] {
        guard let accountId else { return [] }
        return transactions
            .filter {
                $0.accountId == accountId
                    && $0.id != transactionId
                    && $0.refundOfTransactionId == nil
                    && $0.destinationAccountId == nil
                    && $0.occurredAt <= occurredAt
                    && remainingRefundableAmount(for: $0) > 0
            }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    func remainingRefundableAmount(for purchase: Transaction) -> Decimal {
        let refunded = transactions
            .filter { $0.refundOfTransactionId == purchase.id }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return max(0, purchase.amount - refunded)
    }

    func automaticPaymentPreview(
        accountId: UUID,
        amount: Decimal,
        occurredAt: Date
    ) -> [(statement: Statement, amount: Decimal)] {
        var remaining = amount
        var result: [(Statement, Decimal)] = []
        for statement in openStatements(for: accountId) where remaining > 0 {
            let hasEntryByPaymentDate = transactions.contains {
                $0.statementId == statement.id && $0.occurredAt <= occurredAt
            }
            guard hasEntryByPaymentDate else { continue }
            let applied = min(statement.remainingAmount, remaining)
            guard applied > 0 else { continue }
            result.append((statement, applied))
            remaining -= applied
        }
        return result
    }

    /// Payments aplicados a uma Statement (lista de transferências que
    /// pagaram parte/total). `nil` em vez de array vazio quando a Statement
    /// não existe — distingue do caso "existe mas ninguém pagou ainda".
    func payments(for statement: Statement) -> [StatementPayment] {
        statementPayments.filter { $0.statementId == statement.id }
    }

    /// Total já aplicado a uma Statement via payments — soma do
    /// `appliedAmount` de todos os payments daquela Statement.
    func appliedAmount(to statement: Statement) -> Decimal {
        payments(for: statement).reduce(Decimal(0)) { $0 + $1.appliedAmount }
    }

    /// Saldo restante de uma Statement (`total - applied`). Pode ficar
    /// negativo em caso de overpayment.
    func remainingAmount(of statement: Statement) -> Decimal {
        statement.remainingAmount
    }

    func institution(for id: UUID) -> Institution? {
        institutions.first { $0.id == id }
    }

    /// Nome derivado da conta — espelha `AccountStore.displayName(for:)`. Cada
    /// store tem sua cópia porque carrega institutions sob demanda da feature.
    func displayName(for account: Account) -> String {
        Account.displayName(
            for: account,
            institutions: institutions,
            bankAccounts: bankDetails,
            creditCards: creditCards
        )
    }

    var rootCategories: [Category] {
        categories.filter { $0.parentId == nil }
    }

    func subcategories(of parentId: UUID) -> [Category] {
        categories.filter { $0.parentId == parentId }
    }

    private func refreshAfterMutation() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await refreshSnapshot()
        } catch {
            handleRefreshFailure(error)
            throw error
        }
    }

    private func refreshSnapshot() async throws {
        async let transactionPage = container.remoteTransactions.loadPage(
            cursor: nil,
            limit: pageSize
        )
        async let accountSnapshot = container.remoteAccounts.load()
        async let categoryCatalog = container.categoryCatalog.load()
        async let institutionCatalog = container.institutionCatalog.load()
        let (page, accountSnapshotValue, categoryCatalogValue, institutionCatalogValue) = try await (
            transactionPage,
            accountSnapshot,
            categoryCatalog,
            institutionCatalog
        )

        transactions = page.transactions
        nextCursor = page.nextCursor
        hasMoreTransactions = page.nextCursor != nil
        accounts = accountSnapshotValue.accounts
        bankDetails = accountSnapshotValue.bankDetails
        creditCards = accountSnapshotValue.creditCards
        categories = categoryCatalogValue
        institutions = institutionCatalogValue
        // TODO(fase-3): substituir esses placeholders pelo read model remoto
        // de faturas quando o ticket #21 migrar regras de cartão.
        statements = []
        statementPayments = []
        lastError = nil
    }

    private func handleRefreshFailure(_ error: any Error) {
        transactions = []
        nextCursor = nil
        hasMoreTransactions = false
        lastError = error
        NoticeCenter.shared.report(error)
    }
}
