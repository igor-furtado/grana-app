import ComposableArchitecture
import Foundation

@Reducer
struct AccountFormFeature {
    @ObservableState
    struct State: Equatable {
        var existingAccount: AccountListItem?
        var institutions: [Institution]
        var institutionId: UUID?
        var currency = "BRL"
        var branchId = ""
        var accountNumber = ""
        var balanceCents = 0
        var balanceIsNegative = false
        var saveError: String?
        var isSaving = false

        init(
            existingAccount: AccountListItem? = nil,
            institutions: [Institution]
        ) {
            self.existingAccount = existingAccount
            self.institutions = institutions

            if let existingAccount {
                self.institutionId = existingAccount.account.institutionId
                self.currency = existingAccount.account.currency
                self.branchId = existingAccount.bankDetails?.branchId ?? ""
                self.accountNumber = existingAccount.bankDetails?.accountNumber ?? ""

                let cents = Int(truncatingIfNeeded: Converters.decimalToCents(existingAccount.account.initialBalance))
                self.balanceIsNegative = cents < 0
                self.balanceCents = abs(cents)
            } else {
                self.institutionId = availableInstitutions.first?.id
            }
        }

        var availableInstitutions: [Institution] {
            institutions.filter { $0.capabilities.supportedAccountTypes.contains(.checking) }
        }

        var canSave: Bool {
            guard institutionId != nil else { return false }
            return !branchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func mutationInput() -> CheckingAccountMutationInput? {
            guard let institutionId else { return nil }
            let trimmedBranch = branchId.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNumber = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBranch.isEmpty, !trimmedNumber.isEmpty else { return nil }

            let magnitude = Decimal(balanceCents) / 100
            let initialBalance = balanceIsNegative ? -magnitude : magnitude

            return CheckingAccountMutationInput(
                institutionId: institutionId,
                currency: currency,
                branchId: trimmedBranch,
                accountNumber: trimmedNumber,
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
