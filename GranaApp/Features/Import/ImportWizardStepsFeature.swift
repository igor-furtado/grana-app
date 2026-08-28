import ComposableArchitecture
import Foundation

@Reducer
struct OFXImportFeature {
    @ObservableState
    struct State: Equatable {
        var resolutions: [OFXStatementResolution]
        var accounts: [Account]
        var institutions: [Institution]
        var bankDetails: [BankAccountDetails]
        var creditCards: [CreditCardDetails]

        var totalSelected: Int {
            resolutions.reduce(0) { $0 + $1.rows.filter(\.selected).count }
        }

        var allAccountsSelected: Bool {
            resolutions.allSatisfy { $0.accountId != nil }
        }

        func bankKind(for accountId: UUID?) -> InstitutionKind? {
            guard let accountId,
                  let account = accounts.first(where: { $0.id == accountId }),
                  let institutionId = account.institutionId,
                  let institution = institutions.first(where: { $0.id == institutionId })
            else { return nil }
            return institution.kind
        }

        func label(for account: Account) -> String {
            Account.displayName(
                for: account,
                institutions: institutions,
                bankAccounts: bankDetails,
                creditCards: creditCards
            )
        }

        var availableAccounts: [Account] {
            accounts
                .filter { account in
                    guard !account.archived,
                          let institutionId = account.institutionId,
                          let institution = institutions.first(where: { $0.id == institutionId })
                    else { return false }
                    return institution.capabilities.supports(.ofx)
                }
                .sorted { label(for: $0).localizedCaseInsensitiveCompare(label(for: $1)) == .orderedAscending }
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case accountSelected(statementIndex: Int, accountId: UUID?)
        case accountReloaded(statementIndex: Int, resolution: OFXStatementResolution)
        case resolutionsUpdated([OFXStatementResolution])
    }

    @Dependency(\.importClient) private var importClient

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .accountSelected(statementIndex, accountId):
                guard state.resolutions.indices.contains(statementIndex) else { return .none }
                let resolution = state.resolutions[statementIndex]
                return .run { send in
                    let updated = await importClient.reloadOFXResolution(resolution, accountId)
                    await send(.accountReloaded(statementIndex: statementIndex, resolution: updated))
                }

            case let .accountReloaded(statementIndex, resolution):
                guard state.resolutions.indices.contains(statementIndex) else { return .none }
                state.resolutions[statementIndex] = resolution
                return .none

            case let .resolutionsUpdated(resolutions):
                state.resolutions = resolutions
                return .none

            case .binding:
                return .none
            }
        }
    }
}

@Reducer
struct CSVImportFeature {
    @ObservableState
    struct State: Equatable {
        var resolution: CSVStatementResolution
        var accounts: [Account]
        var institutions: [Institution]
        var bankDetails: [BankAccountDetails]
        var creditCards: [CreditCardDetails]

        var creditCardAccounts: [Account] {
            accounts.filter { account in
                guard account.type == .creditCard,
                      !account.archived,
                      let institutionId = account.institutionId,
                      let institution = institutions.first(where: { $0.id == institutionId })
                else { return false }
                return institution.capabilities.supports(.interCreditCardCSV)
            }
        }

        func bankKind(for accountId: UUID?) -> InstitutionKind? {
            guard let accountId,
                  let account = accounts.first(where: { $0.id == accountId }),
                  let institutionId = account.institutionId,
                  let institution = institutions.first(where: { $0.id == institutionId })
            else { return nil }
            return institution.kind
        }

        func accountLabel(for account: Account) -> String {
            Account.displayName(
                for: account,
                institutions: institutions,
                bankAccounts: bankDetails,
                creditCards: creditCards
            )
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case accountSelected(UUID?)
        case accountReloaded(CSVStatementResolution)
        case negativeSelectionChanged(rowId: UUID, isSelected: Bool)
        case resolutionUpdated(CSVStatementResolution)
    }

    @Dependency(\.importClient) private var importClient

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .accountSelected(accountId):
                let resolution = state.resolution
                return .run { send in
                    let refreshed = await importClient.reloadCSVResolution(resolution, accountId)
                    await send(.accountReloaded(refreshed))
                }

            case let .accountReloaded(resolution):
                state.resolution = resolution
                return .none

            case let .negativeSelectionChanged(rowId, isSelected):
                guard let index = state.resolution.negativeRows.firstIndex(where: { $0.id == rowId }) else { return .none }
                state.resolution.negativeRows[index].selected = isSelected
                return .none

            case let .resolutionUpdated(resolution):
                state.resolution = resolution
                return .none

            case .binding:
                return .none
            }
        }
    }
}
