import Foundation
import Supabase

nonisolated struct AccountRemoteSnapshot: @unchecked Sendable {
    var accounts: [Account]
    var bankDetails: [BankAccountDetails]
    var creditCards: [CreditCardDetails]

    static let empty = AccountRemoteSnapshot(
        accounts: [],
        bankDetails: [],
        creditCards: []
    )
}

protocol AccountRemoteRepositoryProtocol: Sendable {
    func load() async throws -> AccountRemoteSnapshot
    func create(input: AccountMutationInput) async throws
    func update(
        accountId: UUID,
        input: AccountMutationInput,
        cycleEffectiveFrom: Date?
    ) async throws
    func delete(accountId: UUID) async throws
}

nonisolated enum AccountRemoteRepositoryError: UserFacingError, Equatable {
    case authenticationRequired
    case unsupportedInstitution
    case invalidTerritorialScope
    case invalidAccountIdentity
    case invalidCheckingAccountDetails
    case invalidCreditCardDetails
    case invalidCurrency
    case accountHasFinancialHistory
    case unexpectedResponse

    var errorTitle: String {
        switch self {
        case .accountHasFinancialHistory:
            return "Não foi possível apagar a conta"
        default:
            return "Falha ao salvar conta"
        }
    }

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "É preciso entrar com sua conta para carregar e salvar contas."
        case .unsupportedInstitution:
            return "A instituição selecionada não suporta esse tipo de conta."
        case .invalidTerritorialScope:
            return "A abrangência selecionada não é suportada pelo app no momento."
        case .invalidAccountIdentity:
            return "Revise os dados de identificação da conta."
        case .invalidCheckingAccountDetails:
            return "Preencha os dados de identificação da conta."
        case .invalidCreditCardDetails:
            return "Informe os 4 dígitos finais e um ciclo válido para cadastrar o cartão."
        case .invalidCurrency:
            return "A moeda informada não é suportada pelo app no momento."
        case .accountHasFinancialHistory:
            return "Não é possível apagar uma conta com transações vinculadas."
        case .unexpectedResponse:
            return "A resposta do backend para contas veio inválida."
        }
    }

    static func from(code: String?) -> AccountRemoteRepositoryError {
        switch code {
        case "unsupported_institution":
            return .unsupportedInstitution
        case "invalid_territorial_scope":
            return .invalidTerritorialScope
        case "invalid_account_identity":
            return .invalidAccountIdentity
        case "invalid_checking_account_details":
            return .invalidCheckingAccountDetails
        case "invalid_credit_card_details":
            return .invalidCreditCardDetails
        case "invalid_currency":
            return .invalidCurrency
        case "account_has_financial_history":
            return .accountHasFinancialHistory
        default:
            return .unexpectedResponse
        }
    }
}

nonisolated struct AccountMutationInput: Hashable {
    var type: AccountType
    var territorialScope: AccountTerritorialScope = .brazilian
    var nickname: String?
    var initialBalance: Decimal
    var archived: Bool
    var institutionId: UUID?
    var currency: String
    var bankDetails: BankAccountDetailsInput?
    var creditCardDetails: CreditCardDetailsInput?
}

nonisolated struct AccountRecordRow: Decodable {
    let id: UUID
    let type: AccountType
    let territorialScope: AccountTerritorialScope?
    let nickname: String?
    let initialBalanceCents: Int64
    let archived: Bool
    let institutionId: UUID?
    let currency: String
    let createdAt: Date
    let updatedAt: Date
    let branchId: String?
    let accountNumber: String?
    let bankName: String?
    let bankCreatedAt: Date?
    let bankUpdatedAt: Date?
    let cardLastFour: String?
    let creditLimitCents: Int64?
    let statementClosingDay: Int?
    let paymentDueDay: Int?
    let cardCreatedAt: Date?
    let cardUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case territorialScope = "territorial_scope"
        case nickname
        case initialBalanceCents = "initial_balance_cents"
        case archived
        case institutionId = "institution_id"
        case currency
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case branchId = "branch_id"
        case accountNumber = "account_number"
        case bankName = "bank_name"
        case bankCreatedAt = "bank_created_at"
        case bankUpdatedAt = "bank_updated_at"
        case cardLastFour = "card_last_four"
        case creditLimitCents = "credit_limit_cents"
        case statementClosingDay = "statement_closing_day"
        case paymentDueDay = "payment_due_day"
        case cardCreatedAt = "card_created_at"
        case cardUpdatedAt = "card_updated_at"
    }
}

nonisolated struct AccountMutationResponse: Decodable {
    let ok: Bool
    let code: String?
    let accountId: UUID?

    enum CodingKeys: String, CodingKey {
        case ok
        case code
        case accountId = "account_id"
    }
}

protocol AccountRemoteStore: Sendable {
    func fetchAccounts() async throws -> [AccountRecordRow]
    func createAccount(request: CreateAccountRequest) async throws -> AccountMutationResponse
    func updateAccount(request: UpdateAccountRequest) async throws -> AccountMutationResponse
    func deleteAccount(request: DeleteAccountRequest) async throws -> AccountMutationResponse
}

actor SupabaseAccountRemoteStore: AccountRemoteStore {
    private let authClient: any AuthClientProtocol
    private let supabaseURL: String
    private let supabaseAnonKey: String
    private var client: SupabaseClient?

    init(
        authClient: any AuthClientProtocol,
        supabaseURL: String? = nil,
        supabaseAnonKey: String? = nil
    ) {
        self.authClient = authClient
        self.supabaseURL = supabaseURL ?? Config.supabaseURL
        self.supabaseAnonKey = supabaseAnonKey ?? Config.supabaseAnonKey
    }

    func fetchAccounts() async throws -> [AccountRecordRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_list_accounts")
            .execute()
            .value
    }

    func createAccount(request: CreateAccountRequest) async throws -> AccountMutationResponse {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_create_account", params: request)
            .execute()
            .value
    }

    func updateAccount(request: UpdateAccountRequest) async throws -> AccountMutationResponse {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_update_account", params: request)
            .execute()
            .value
    }

    func deleteAccount(request: DeleteAccountRequest) async throws -> AccountMutationResponse {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_delete_account", params: request)
            .execute()
            .value
    }

    private func resolvedClient() throws -> SupabaseClient {
        if let client {
            return client
        }

        let client = try SupabaseAuthenticatedClientFactory.makeClient(
            authClient: authClient,
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey
        )
        self.client = client
        return client
    }
}

final class AccountRemoteRepository: AccountRemoteRepositoryProtocol, Sendable {
    private let remoteStore: any AccountRemoteStore

    init(remoteStore: any AccountRemoteStore) {
        self.remoteStore = remoteStore
    }

    func load() async throws -> AccountRemoteSnapshot {
        let rows = try await remoteStore.fetchAccounts()
        var accounts: [Account] = []
        var bankDetails: [BankAccountDetails] = []
        var creditCards: [CreditCardDetails] = []

        for row in rows {
            accounts.append(Account(
                id: row.id,
                type: row.type,
                territorialScope: row.territorialScope ?? .brazilian,
                nickname: row.nickname,
                initialBalance: Converters.centsToDecimal(row.initialBalanceCents),
                archived: row.archived,
                institutionId: row.institutionId,
                currency: row.currency,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            ))

            if let accountNumber = row.accountNumber {
                bankDetails.append(BankAccountDetails(
                    accountId: row.id,
                    branchId: row.branchId,
                    accountNumber: accountNumber,
                    bankName: row.bankName,
                    createdAt: row.bankCreatedAt ?? row.createdAt,
                    updatedAt: row.bankUpdatedAt ?? row.updatedAt
                ))
            }

            switch (row.cardLastFour, row.statementClosingDay, row.paymentDueDay) {
            case let (cardLastFour?, statementClosingDay?, paymentDueDay?):
                creditCards.append(CreditCardDetails(
                    accountId: row.id,
                    cardLastFour: cardLastFour,
                    creditLimit: row.creditLimitCents.map(Converters.centsToDecimal(_:)),
                    statementClosingDay: statementClosingDay,
                    paymentDueDay: paymentDueDay,
                    createdAt: row.cardCreatedAt ?? row.createdAt,
                    updatedAt: row.cardUpdatedAt ?? row.updatedAt
                ))
            default:
                break
            }
        }

        return AccountRemoteSnapshot(
            accounts: accounts,
            bankDetails: bankDetails,
            creditCards: creditCards
        )
    }

    func create(input: AccountMutationInput) async throws {
        let response = try await remoteStore.createAccount(
            request: CreateAccountRequest(input: input)
        )
        try validate(response)
    }

    func update(
        accountId: UUID,
        input: AccountMutationInput,
        cycleEffectiveFrom: Date?
    ) async throws {
        let response = try await remoteStore.updateAccount(
            request: UpdateAccountRequest(
                accountId: accountId,
                input: input,
                cycleEffectiveFrom: cycleEffectiveFrom
            )
        )
        try validate(response)
    }

    func delete(accountId: UUID) async throws {
        let response = try await remoteStore.deleteAccount(
            request: DeleteAccountRequest(accountId: accountId)
        )
        try validate(response)
    }

    private func validate(_ response: AccountMutationResponse) throws {
        guard response.ok else {
            throw AccountRemoteRepositoryError.from(code: response.code)
        }
    }
}

struct StaticAccountRemoteRepository: AccountRemoteRepositoryProtocol {
    let snapshot: AccountRemoteSnapshot

    func load() async throws -> AccountRemoteSnapshot {
        snapshot
    }

    func create(input _: AccountMutationInput) async throws {}

    func update(
        accountId _: UUID,
        input _: AccountMutationInput,
        cycleEffectiveFrom _: Date?
    ) async throws {}

    func delete(accountId _: UUID) async throws {}
}

struct AuthRequiredAccountRemoteRepository: AccountRemoteRepositoryProtocol {
    func load() async throws -> AccountRemoteSnapshot {
        throw AccountRemoteRepositoryError.authenticationRequired
    }

    func create(input _: AccountMutationInput) async throws {
        throw AccountRemoteRepositoryError.authenticationRequired
    }

    func update(
        accountId _: UUID,
        input _: AccountMutationInput,
        cycleEffectiveFrom _: Date?
    ) async throws {
        throw AccountRemoteRepositoryError.authenticationRequired
    }

    func delete(accountId _: UUID) async throws {
        throw AccountRemoteRepositoryError.authenticationRequired
    }
}

nonisolated struct CreateAccountRequest: Encodable {
    let pType: String
    let pTerritorialScope: String
    let pNickname: String?
    let pInitialBalanceCents: Int64
    let pArchived: Bool
    let pInstitutionId: UUID?
    let pCurrency: String
    let pBranchId: String?
    let pAccountNumber: String?
    let pBankName: String?
    let pCardLastFour: String?
    let pCreditLimitCents: Int64?
    let pStatementClosingDay: Int?
    let pPaymentDueDay: Int?

    init(input: AccountMutationInput) {
        self.pType = input.type.rawValue
        self.pTerritorialScope = input.territorialScope.rawValue
        self.pNickname = input.nickname
        self.pInitialBalanceCents = Converters.decimalToCents(input.initialBalance)
        self.pArchived = input.archived
        self.pInstitutionId = input.institutionId
        self.pCurrency = input.currency
        self.pBranchId = input.bankDetails?.branchId
        self.pAccountNumber = input.bankDetails?.accountNumber
        self.pBankName = input.bankDetails?.bankName
        self.pCardLastFour = input.creditCardDetails?.cardLastFour
        self.pCreditLimitCents = input.creditCardDetails?.creditLimit.map(Converters.decimalToCents(_:))
        self.pStatementClosingDay = input.creditCardDetails?.statementClosingDay
        self.pPaymentDueDay = input.creditCardDetails?.paymentDueDay
    }

    enum CodingKeys: String, CodingKey {
        case pType = "p_type"
        case pTerritorialScope = "p_territorial_scope"
        case pNickname = "p_nickname"
        case pInitialBalanceCents = "p_initial_balance_cents"
        case pArchived = "p_archived"
        case pInstitutionId = "p_institution_id"
        case pCurrency = "p_currency"
        case pBranchId = "p_branch_id"
        case pAccountNumber = "p_account_number"
        case pBankName = "p_bank_name"
        case pCardLastFour = "p_card_last_four"
        case pCreditLimitCents = "p_credit_limit_cents"
        case pStatementClosingDay = "p_statement_closing_day"
        case pPaymentDueDay = "p_payment_due_day"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pType, forKey: .pType)
        try container.encode(pTerritorialScope, forKey: .pTerritorialScope)
        try container.encode(pNickname, forKey: .pNickname)
        try container.encode(pInitialBalanceCents, forKey: .pInitialBalanceCents)
        try container.encode(pArchived, forKey: .pArchived)
        try container.encode(pInstitutionId, forKey: .pInstitutionId)
        try container.encode(pCurrency, forKey: .pCurrency)
        try container.encode(pBranchId, forKey: .pBranchId)
        try container.encode(pAccountNumber, forKey: .pAccountNumber)
        try container.encode(pBankName, forKey: .pBankName)
        try container.encode(pCardLastFour, forKey: .pCardLastFour)
        try container.encode(pCreditLimitCents, forKey: .pCreditLimitCents)
        try container.encode(pStatementClosingDay, forKey: .pStatementClosingDay)
        try container.encode(pPaymentDueDay, forKey: .pPaymentDueDay)
    }
}

nonisolated struct UpdateAccountRequest: Encodable {
    let pAccountId: UUID
    let pType: String
    let pTerritorialScope: String
    let pNickname: String?
    let pInitialBalanceCents: Int64
    let pArchived: Bool
    let pInstitutionId: UUID?
    let pCurrency: String
    let pBranchId: String?
    let pAccountNumber: String?
    let pBankName: String?
    let pCardLastFour: String?
    let pCreditLimitCents: Int64?
    let pStatementClosingDay: Int?
    let pPaymentDueDay: Int?
    let pCycleEffectiveFrom: Date?

    init(
        accountId: UUID,
        input: AccountMutationInput,
        cycleEffectiveFrom: Date?
    ) {
        self.pAccountId = accountId
        self.pType = input.type.rawValue
        self.pTerritorialScope = input.territorialScope.rawValue
        self.pNickname = input.nickname
        self.pInitialBalanceCents = Converters.decimalToCents(input.initialBalance)
        self.pArchived = input.archived
        self.pInstitutionId = input.institutionId
        self.pCurrency = input.currency
        self.pBranchId = input.bankDetails?.branchId
        self.pAccountNumber = input.bankDetails?.accountNumber
        self.pBankName = input.bankDetails?.bankName
        self.pCardLastFour = input.creditCardDetails?.cardLastFour
        self.pCreditLimitCents = input.creditCardDetails?.creditLimit.map(Converters.decimalToCents(_:))
        self.pStatementClosingDay = input.creditCardDetails?.statementClosingDay
        self.pPaymentDueDay = input.creditCardDetails?.paymentDueDay
        self.pCycleEffectiveFrom = cycleEffectiveFrom
    }

    enum CodingKeys: String, CodingKey {
        case pAccountId = "p_account_id"
        case pType = "p_type"
        case pTerritorialScope = "p_territorial_scope"
        case pNickname = "p_nickname"
        case pInitialBalanceCents = "p_initial_balance_cents"
        case pArchived = "p_archived"
        case pInstitutionId = "p_institution_id"
        case pCurrency = "p_currency"
        case pBranchId = "p_branch_id"
        case pAccountNumber = "p_account_number"
        case pBankName = "p_bank_name"
        case pCardLastFour = "p_card_last_four"
        case pCreditLimitCents = "p_credit_limit_cents"
        case pStatementClosingDay = "p_statement_closing_day"
        case pPaymentDueDay = "p_payment_due_day"
        case pCycleEffectiveFrom = "p_cycle_effective_from"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pAccountId, forKey: .pAccountId)
        try container.encode(pType, forKey: .pType)
        try container.encode(pTerritorialScope, forKey: .pTerritorialScope)
        try container.encode(pNickname, forKey: .pNickname)
        try container.encode(pInitialBalanceCents, forKey: .pInitialBalanceCents)
        try container.encode(pArchived, forKey: .pArchived)
        try container.encode(pInstitutionId, forKey: .pInstitutionId)
        try container.encode(pCurrency, forKey: .pCurrency)
        try container.encode(pBranchId, forKey: .pBranchId)
        try container.encode(pAccountNumber, forKey: .pAccountNumber)
        try container.encode(pBankName, forKey: .pBankName)
        try container.encode(pCardLastFour, forKey: .pCardLastFour)
        try container.encode(pCreditLimitCents, forKey: .pCreditLimitCents)
        try container.encode(pStatementClosingDay, forKey: .pStatementClosingDay)
        try container.encode(pPaymentDueDay, forKey: .pPaymentDueDay)
        try container.encode(pCycleEffectiveFrom, forKey: .pCycleEffectiveFrom)
    }
}

nonisolated struct DeleteAccountRequest: Encodable {
    let pAccountId: UUID

    init(accountId: UUID) {
        self.pAccountId = accountId
    }

    enum CodingKeys: String, CodingKey {
        case pAccountId = "p_account_id"
    }
}
