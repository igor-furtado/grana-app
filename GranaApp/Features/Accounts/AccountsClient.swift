import ComposableArchitecture
import Foundation

struct AccountListItem: Equatable, Identifiable {
    let account: Account
    let institution: Institution?
    let bankDetails: BankAccountDetails?
    let currentBalance: Decimal

    var id: UUID {
        account.id
    }

    var displayName: String {
        Account.displayName(
            for: account,
            institutions: institution.map { [$0] } ?? [],
            bankAccounts: bankDetails.map { [$0] } ?? [],
            creditCards: []
        )
    }

    var institutionName: String {
        institution?.name ?? "Sem instituição"
    }

    var institutionKind: InstitutionKind {
        institution?.kind ?? .other
    }

    var statusText: String {
        account.archived ? "Arquivada" : "Ativa"
    }

    var statusRank: Int {
        account.archived ? 1 : 0
    }
}

struct AccountsSnapshot: Equatable {
    var items: [AccountListItem]
    var institutions: [Institution]

    static let empty = AccountsSnapshot(items: [], institutions: [])
}

struct CheckingAccountMutationInput: Equatable {
    var institutionId: UUID?
    var currency: String = "BRL"
    var branchId: String?
    var accountNumber: String
    var initialBalance: Decimal
}

struct AccountsClient {
    var loadList: @Sendable () async throws -> AccountsSnapshot
    var create: @Sendable (_ input: CheckingAccountMutationInput) async throws -> Void
    var update: @Sendable (_ accountId: UUID, _ archived: Bool, _ input: CheckingAccountMutationInput) async throws
        -> Void
    var setArchived: @Sendable (_ accountId: UUID, _ archived: Bool) async throws -> Void
    var delete: @Sendable (_ accountId: UUID) async throws -> Void

    static func live(container: AppContainer) -> AccountsClient {
        AccountsClient(
            loadList: {
                async let accountSnapshot = container.remoteAccounts.load()
                async let institutionCatalog = container.institutionCatalog.load()
                async let categoryCatalog = container.categoryCatalog.load()
                async let remoteTransactions = container.remoteTransactions.loadAll()
                let (accounts, institutions, categories, transactions) = try await (
                    accountSnapshot,
                    institutionCatalog,
                    categoryCatalog,
                    remoteTransactions
                )

                let balances = calculateBalances(
                    accounts: accounts.accounts,
                    categories: categories,
                    transactions: transactions
                )

                let items = accounts.accounts
                    .filter { $0.type == .checking }
                    .map { account in
                        AccountListItem(
                            account: account,
                            institution: institutions.first { $0.id == account.institutionId },
                            bankDetails: accounts.bankDetails.first { $0.accountId == account.id },
                            currentBalance: balances[account.id] ?? account.initialBalance
                        )
                    }

                return AccountsSnapshot(items: items, institutions: institutions)
            },
            create: { input in
                try await container.remoteAccounts.create(
                    input: accountMutationInput(from: input, archived: false)
                )
            },
            update: { accountId, archived, input in
                try await container.remoteAccounts.update(
                    accountId: accountId,
                    input: accountMutationInput(from: input, archived: archived),
                    cycleEffectiveFrom: nil
                )
            },
            setArchived: { accountId, archived in
                let snapshot = try await container.remoteAccounts.load()
                guard let account = snapshot.accounts.first(where: { $0.id == accountId }),
                      let details = snapshot.bankDetails.first(where: { $0.accountId == accountId })
                else { return }

                try await container.remoteAccounts.update(
                    accountId: accountId,
                    input: accountMutationInput(
                        from: CheckingAccountMutationInput(
                            institutionId: account.institutionId,
                            currency: account.currency,
                            branchId: details.branchId,
                            accountNumber: details.accountNumber,
                            initialBalance: account.initialBalance
                        ),
                        archived: archived
                    ),
                    cycleEffectiveFrom: nil
                )
            },
            delete: { accountId in
                try await container.remoteAccounts.delete(accountId: accountId)
            }
        )
    }

    private static func accountMutationInput(
        from input: CheckingAccountMutationInput,
        archived: Bool
    ) -> AccountMutationInput {
        AccountMutationInput(
            type: .checking,
            initialBalance: input.initialBalance,
            archived: archived,
            institutionId: input.institutionId,
            currency: input.currency,
            bankDetails: BankAccountDetailsInput(
                branchId: input.branchId,
                accountNumber: input.accountNumber
            ),
            creditCardDetails: nil
        )
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

extension AccountsClient: DependencyKey {
    static let liveValue = AccountsClient(
        loadList: { .empty },
        create: { _ in },
        update: { _, _, _ in },
        setArchived: { _, _ in },
        delete: { _ in }
    )

    static let testValue = AccountsClient(
        loadList: unimplemented("AccountsClient.loadList"),
        create: unimplemented("AccountsClient.create"),
        update: unimplemented("AccountsClient.update"),
        setArchived: unimplemented("AccountsClient.setArchived"),
        delete: unimplemented("AccountsClient.delete")
    )
}

extension DependencyValues {
    var accountsClient: AccountsClient {
        get { self[AccountsClient.self] }
        set { self[AccountsClient.self] = newValue }
    }
}
