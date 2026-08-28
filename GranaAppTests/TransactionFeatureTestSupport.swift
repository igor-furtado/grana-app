import Foundation
@testable import GranaApp

func makeTransactionsFixture() -> (
    institution: Institution,
    category: GranaApp.Category,
    account: Account,
    transaction: Transaction
) {
    let institution = makeRemoteInstitution(
        id: UUID(),
        code: "077",
        name: "Banco Inter",
        kind: .inter,
        accountTypes: [.checking]
    )
    let category = makeRemoteCategory(
        id: UUID(),
        name: "Restaurantes",
        kind: .expense,
        slug: "alimentacao"
    )
    let account = makeRemoteCheckingAccount(
        id: UUID(),
        institutionId: institution.id,
        balance: 300
    )
    let transaction = makeTransaction(
        id: UUID(),
        accountId: account.id,
        categoryId: category.id,
        amount: 42
    )
    return (institution, category, account, transaction)
}

func makeTransactionsSnapshot(
    page: TransactionRemotePage = .empty,
    accounts: [Account] = [],
    institutions: [Institution] = [],
    categories: [GranaApp.Category] = [],
    statements: [Statement] = [],
    statementPayments: [StatementPayment] = []
) -> TransactionsSnapshot {
    let accountSnapshot = makeRemoteSnapshot(accounts: accounts)
    return TransactionsSnapshot(
        page: page,
        accounts: accounts,
        institutions: institutions,
        bankDetails: accountSnapshot.bankDetails,
        creditCards: accountSnapshot.creditCards,
        categories: categories,
        statements: statements,
        statementPayments: statementPayments
    )
}

func makeTransactionFormState(
    data: (
        institution: Institution,
        category: GranaApp.Category,
        account: Account,
        transaction: Transaction
    ),
    existing: Transaction? = nil,
    transactions: [Transaction] = [],
    categories: [GranaApp.Category]? = nil
) -> TransactionFormFeature.State {
    let accountSnapshot = makeRemoteSnapshot(accounts: [data.account])
    return TransactionFormFeature.State(
        existing: existing,
        transactions: transactions,
        accounts: [data.account],
        institutions: [data.institution],
        bankDetails: accountSnapshot.bankDetails,
        creditCards: accountSnapshot.creditCards,
        categories: categories ?? [data.category],
        statements: [],
        statementPayments: []
    )
}

func makeTransaction(
    id: UUID,
    accountId: UUID,
    categoryId: UUID,
    amount: Decimal,
    occurredAt: Date = Date(),
    description: String = "Transação",
    notes: String? = nil,
    refundOfTransactionId: UUID? = nil,
    destinationAccountId: UUID? = nil,
    createdAt: Date = Date().addingTimeInterval(-5)
) -> Transaction {
    Transaction(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        subcategoryId: nil,
        amount: amount,
        occurredAt: occurredAt,
        description: description,
        notes: notes,
        destinationAccountId: destinationAccountId,
        refundOfTransactionId: refundOfTransactionId,
        createdAt: createdAt,
        updatedAt: createdAt
    )
}

func makeRemoteCategory(
    id: UUID,
    name: String,
    kind: CategoryKind,
    slug: String
) -> GranaApp.Category {
    GranaApp.Category(
        id: id,
        parentId: nil,
        name: name,
        kind: kind,
        slug: slug,
        createdAt: Date()
    )
}

func makeRemoteInstitution(
    id: UUID,
    code: String,
    name: String,
    kind: InstitutionKind,
    accountTypes: Set<AccountType>
) -> Institution {
    Institution(
        id: id,
        code: code,
        name: name,
        kind: kind,
        capabilities: InstitutionCapabilities(
            supportedAccountTypes: accountTypes,
            supportedImportFormats: []
        ),
        createdAt: Date(),
        updatedAt: Date()
    )
}

func makeRemoteCheckingAccount(
    id: UUID,
    institutionId: UUID,
    balance: Decimal
) -> Account {
    Account(
        id: id,
        type: .checking,
        initialBalance: balance,
        archived: false,
        institutionId: institutionId,
        currency: "BRL",
        createdAt: Date(),
        updatedAt: Date()
    )
}

func makeRemoteCreditCardAccount(
    id: UUID,
    institutionId: UUID
) -> Account {
    Account(
        id: id,
        type: .creditCard,
        initialBalance: 0,
        archived: false,
        institutionId: institutionId,
        currency: "BRL",
        createdAt: Date(),
        updatedAt: Date()
    )
}

func makeRemoteSnapshot(
    accounts: [Account]
) -> AccountRemoteSnapshot {
    AccountRemoteSnapshot(
        accounts: accounts,
        bankDetails: accounts
            .filter { $0.type == .checking }
            .map { account in
                BankAccountDetails(
                    accountId: account.id,
                    branchId: "0001",
                    accountNumber: "1234",
                    createdAt: account.createdAt,
                    updatedAt: account.updatedAt
                )
            },
        creditCards: accounts
            .filter { $0.type == .creditCard }
            .map { account in
                CreditCardDetails(
                    accountId: account.id,
                    cardLastFour: "1234",
                    creditLimit: 1000,
                    statementClosingDay: 8,
                    paymentDueDay: 15,
                    createdAt: account.createdAt,
                    updatedAt: account.updatedAt
                )
            }
    )
}

func makeStatement(
    accountId: UUID,
    amount: Decimal
) -> Statement {
    let now = Date()
    return Statement(
        id: UUID(),
        accountId: accountId,
        closingDate: now,
        dueDate: now.addingTimeInterval(86400 * 10),
        netAmount: amount,
        creditReceived: 0,
        paymentApplied: 0,
        settledAt: nil,
        createdAt: now,
        updatedAt: now
    )
}

actor TransactionDeleteRecorder {
    private var recordedIds: [UUID] = []

    func record(_ id: UUID) {
        recordedIds.append(id)
    }

    func deletedIds() -> [UUID] {
        recordedIds
    }
}
