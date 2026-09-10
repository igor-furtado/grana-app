import ComposableArchitecture
import Foundation

@Reducer
struct AccountFormFeature {
    struct CheckingAccountPrefill: Equatable {
        var institutionId: UUID?
        var branchId: String
        var accountNumber: String
    }

    @ObservableState
    struct State: Equatable {
        var existingAccount: AccountListItem?
        var institutions: [Institution]
        var type: AccountType = .checking
        var territorialScope: AccountTerritorialScope = .brazilian
        var nickname = ""
        var institutionId: UUID?
        var currency = "BRL"
        var branchId = ""
        var accountNumber = ""
        var bankName = ""
        var balanceCents = 0
        var balanceIsNegative = false
        var saveError: String?
        var isSaving = false

        init(
            existingAccount: AccountListItem? = nil,
            institutions: [Institution],
            checkingAccountPrefill: CheckingAccountPrefill? = nil
        ) {
            self.existingAccount = existingAccount
            self.institutions = institutions

            if let existingAccount {
                self.type = existingAccount.account.type
                self.territorialScope = existingAccount.account.territorialScope
                self.nickname = existingAccount.account.nickname ?? ""
                self.institutionId = existingAccount.account.institutionId
                self.currency = existingAccount.account.currency
                self.branchId = existingAccount.bankDetails?.branchId ?? ""
                self.accountNumber = existingAccount.bankDetails?.accountNumber ?? ""
                self.bankName = existingAccount.bankDetails?.bankName ?? ""

                let cents = Int(truncatingIfNeeded: Converters.decimalToCents(existingAccount.account.initialBalance))
                self.balanceIsNegative = cents < 0
                self.balanceCents = abs(cents)
            } else {
                self.institutionId = checkingAccountPrefill?.institutionId ?? availableInstitutions.first?.id
                self.branchId = checkingAccountPrefill?.branchId ?? ""
                self.accountNumber = checkingAccountPrefill?.accountNumber ?? ""
            }
        }

        var availableAccountTypes: [AccountType] {
            [.checking, .investment]
        }

        var availableInstitutions: [Institution] {
            institutions.filter { $0.capabilities.supportedAccountTypes.contains(type) }
        }

        var availableCurrencies: [String] {
            switch territorialScope {
            case .brazilian: ["BRL"]
            case .global: ["USD"]
            }
        }

        var canSave: Bool {
            guard institutionId != nil else { return false }
            guard !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            if territorialScope == .global {
                return !bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && availableCurrencies.contains(currency)
            }
            return currency == "BRL"
        }

        func mutationInput() -> CheckingAccountMutationInput? {
            guard let institutionId else { return nil }
            let trimmedBranch = branchId.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNumber = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBankName = bankName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedNumber.isEmpty else { return nil }
            guard territorialScope == .brazilian || !trimmedBankName.isEmpty else { return nil }

            let magnitude = Decimal(balanceCents) / 100
            let initialBalance = balanceIsNegative ? -magnitude : magnitude

            return CheckingAccountMutationInput(
                type: type,
                territorialScope: territorialScope,
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                institutionId: institutionId,
                currency: currency,
                branchId: territorialScope == .brazilian ? trimmedBranch.nilIfEmpty : nil,
                accountNumber: trimmedNumber,
                bankName: territorialScope == .global ? trimmedBankName : nil,
                initialBalance: initialBalance
            )
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case cancelButtonTapped
        case saveButtonTapped
        case saveSucceeded
        case saveFailed(String)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case cancel
        case saved
    }

    @Dependency(\.accountsClient) private var accountsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.type):
                if !state.availableInstitutions.contains(where: { $0.id == state.institutionId }) {
                    state.institutionId = state.availableInstitutions.first?.id
                }
                return .none

            case .binding(\.territorialScope):
                state.currency = state.availableCurrencies.first ?? "BRL"
                if state.territorialScope == .global {
                    state.branchId = ""
                } else {
                    state.bankName = ""
                }
                return .none

            case .binding:
                return .none

            case .cancelButtonTapped:
                return .send(.delegate(.cancel))

            case .saveButtonTapped:
                guard state.canSave else { return .none }
                return save(&state)

            case .saveSucceeded:
                state.isSaving = false
                return .send(.delegate(.saved))

            case let .saveFailed(message):
                state.isSaving = false
                state.saveError = message
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func save(_ state: inout State) -> Effect<Action> {
        guard let input = state.mutationInput() else { return .none }
        state.isSaving = true
        state.saveError = nil
        return .run { [existingAccount = state.existingAccount] send in
            do {
                if let existingAccount {
                    try await accountsClient.update(
                        existingAccount.id,
                        existingAccount.account.archived,
                        input
                    )
                } else {
                    try await accountsClient.create(input)
                }
                await send(.saveSucceeded)
            } catch {
                await noticeClient.report(error, "Falha ao salvar conta")
                await send(.saveFailed(error.localizedDescription))
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
