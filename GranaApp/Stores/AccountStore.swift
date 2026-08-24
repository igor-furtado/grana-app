import Foundation
import Observation
import OSLog

/// Estado observável da feature Contas — lista de `Account` + lookups de
/// `Institution`, `BankAccountDetails` e `CreditCardDetails`. Nesta fatia,
/// contas passam a carregar por contratos remotos explícitos (`load` /
/// `refresh`) em vez de streams locais.
@MainActor
@Observable
final class AccountStore {
    /// Escape hatch transitório enquanto detalhe de cartão e transações
    /// ainda não migraram para read models remotos dedicados.
    let container: AppContainer

    private(set) var accounts: [Account] = []
    private(set) var institutions: [Institution] = []
    private(set) var bankDetails: [BankAccountDetails] = []
    private(set) var creditCards: [CreditCardDetails] = []
    private(set) var statements: [Statement] = []
    /// Read model transitório vindo da camada local enquanto transações e
    /// agregações de conta ainda não migraram para contratos remotos.
    private(set) var balances: [UUID: Decimal] = [:]
    private(set) var isLoading = false
    var lastError: Error?

    init(container: AppContainer) {
        self.container = container
    }

    func load() async {
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let accountSnapshot = container.remoteAccounts.load()
            async let institutionCatalog = container.institutionCatalog.load()
            async let statementSnapshot = container.remoteStatements.load()
            async let categoryCatalog = container.categoryCatalog.load()
            async let remoteTransactions = container.remoteTransactions.loadAll()
            let (snapshot, institutions, statementSnapshotValue, categories, loadedTransactions) = try await (
                accountSnapshot,
                institutionCatalog,
                statementSnapshot,
                categoryCatalog,
                remoteTransactions
            )

            accounts = snapshot.accounts
            bankDetails = snapshot.bankDetails
            creditCards = snapshot.creditCards
            self.institutions = institutions
            statements = statementSnapshotValue.statements
            balances = Self.calculateBalances(
                accounts: snapshot.accounts,
                categories: categories,
                transactions: loadedTransactions
            )
            lastError = nil
        } catch {
            lastError = error
            NoticeCenter.shared.report(error)
        }
    }

    func refreshInstitutions() async {
        do {
            institutions = try await container.institutionCatalog.load()
            lastError = nil
        } catch {
            lastError = error
            NoticeCenter.shared.report(error)
        }
    }

    // MARK: - Lookups

    func institution(for id: UUID) -> Institution? {
        institutions.first { $0.id == id }
    }

    func institution(forAccount account: Account) -> Institution? {
        guard let id = account.institutionId else { return nil }
        return institution(for: id)
    }

    func supportedInstitutions(for accountType: AccountType) -> [Institution] {
        institutions.filter { $0.capabilities.supportedAccountTypes.contains(accountType) }
    }

    func bankDetails(for accountId: UUID) -> BankAccountDetails? {
        bankDetails.first { $0.accountId == accountId }
    }

    func creditCard(for accountId: UUID) -> CreditCardDetails? {
        creditCards.first { $0.accountId == accountId }
    }

    /// Statement em aberto mais próxima do fechamento pra uma conta-cartão.
    /// Transitório até a fatia de faturas ganhar seu próprio read model remoto.
    func nextStatement(for accountId: UUID) -> Statement? {
        statements
            .filter {
                $0.accountId == accountId
                    && ($0.status() == .forming || $0.remainingAmount > 0)
            }
            .min(by: { $0.closingDate < $1.closingDate })
    }

    /// Saldo atual da conta. Enquanto a fatia de transações ainda não migrou,
    /// este valor vem do read model local e cai pro saldo inicial se não
    /// houver agregado calculado.
    func currentBalance(for account: Account) -> Decimal {
        balances[account.id] ?? account.initialBalance
    }

    /// Nome derivado da conta pra exibição. Como `Account` não armazena nome a
    /// partir da Fase 4.5, o display vem da combinação `instituição + tipo +
    /// identificador específico` (número da conta pra bancos, ••••last4 pra
    /// cartão). Reusa a versão estática — qualquer caller que tenha
    /// `institutions`/`bankDetails`/`creditCards` em mãos pode resolver sem
    /// passar pelo store.
    func displayName(for account: Account) -> String {
        Account.displayName(
            for: account,
            institutions: institutions,
            bankAccounts: bankDetails,
            creditCards: creditCards
        )
    }

    // MARK: - Mutations

    func create(
        type: AccountType,
        initialBalance: Decimal,
        institutionId: UUID?,
        currency: String,
        bankDetails: BankAccountDetailsInput? = nil,
        creditCardDetails: CreditCardDetailsInput? = nil
    ) async throws {
        let input = AccountMutationInput(
            type: type,
            initialBalance: type == .creditCard ? 0 : initialBalance,
            archived: false,
            institutionId: institutionId,
            currency: currency,
            bankDetails: bankDetails,
            creditCardDetails: creditCardDetails
        )
        try await container.remoteAccounts.create(input: input)
        await refresh()
    }

    func update(
        _ account: Account,
        bankDetails: BankAccountDetailsInput? = nil,
        creditCardDetails: CreditCardDetailsInput? = nil,
        cycleEffectiveFrom: Date? = nil
    ) async throws {
        let input = AccountMutationInput(
            type: account.type,
            initialBalance: account.type == .creditCard ? 0 : account.initialBalance,
            archived: account.archived,
            institutionId: account.institutionId,
            currency: account.currency,
            bankDetails: bankDetails,
            creditCardDetails: creditCardDetails
        )
        try await container.remoteAccounts.update(
            accountId: account.id,
            input: input,
            cycleEffectiveFrom: cycleEffectiveFrom
        )
        await refresh()
    }

    func delete(id: UUID) async throws {
        try await container.remoteAccounts.delete(accountId: id)
        await refresh()
    }

    /// Toggle de arquivamento. Conta arquivada some dos pickers do form de
    /// transação e dos totais do dashboard, mas mantém histórico vinculado.
    /// Não toca em details (preserva agência/cartão pra reativação).
    func setArchived(_ account: Account, archived: Bool) async throws {
        var copy = account
        copy.archived = archived
        copy.updatedAt = Date()
        // Repassa os details existentes pra `update` não dropar eles no
        // delete-then-insert da tabela-irmã.
        let bank = bankDetails.first { $0.accountId == account.id }
            .map { BankAccountDetailsInput(branchId: $0.branchId, accountNumber: $0.accountNumber) }
        let card = creditCards.first { $0.accountId == account.id }
            .map {
                CreditCardDetailsInput(
                    cardLastFour: $0.cardLastFour,
                    creditLimit: $0.creditLimit,
                    statementClosingDay: $0.statementClosingDay,
                    paymentDueDay: $0.paymentDueDay
                )
            }
        try await update(copy, bankDetails: bank, creditCardDetails: card)
    }

    private static func calculateBalances(
        accounts: [Account],
        categories: [Category],
        transactions: [Transaction]
    ) -> [UUID: Decimal] {
        let categoryKinds = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.kind) })
        var balances = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.initialBalance) })

        for transaction in transactions {
            guard let kind = categoryKinds[transaction.categoryId] else { continue }

            switch kind {
            case .income:
                balances[transaction.accountId, default: 0] += transaction.amount
            case .expense:
                balances[transaction.accountId, default: 0] -= transaction.amount
            case .transfer:
                guard let destinationAccountId = transaction.destinationAccountId else { continue }
                balances[transaction.accountId, default: 0] -= transaction.amount
                balances[destinationAccountId, default: 0] += transaction.amount
            }
        }

        return balances
    }
}

/// DTO de entrada pra `AccountStore.create`/`update`. Carrega só o que o
/// usuário digitou — `accountId`/`createdAt`/`updatedAt` o store define.
nonisolated struct BankAccountDetailsInput: Hashable, Sendable {
    var branchId: String?
    var accountNumber: String
}

nonisolated struct CreditCardDetailsInput: Hashable, Sendable {
    var cardLastFour: String
    var creditLimit: Decimal?
    var statementClosingDay: Int
    var paymentDueDay: Int
}
