import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var accounts = AccountsFeature.State()
        var creditCards = CreditCardsFeature.State()
        var importFeature = ImportFeature.State()
        var transactions = TransactionsFeature.State()
        var categories = CategoriesFeature.State()
        var supportedInstitutions = SupportedInstitutionsFeature.State()
    }

    enum Action: Equatable {
        case accounts(AccountsFeature.Action)
        case creditCards(CreditCardsFeature.Action)
        case importFeature(ImportFeature.Action)
        case transactions(TransactionsFeature.Action)
        case categories(CategoriesFeature.Action)
        case supportedInstitutions(SupportedInstitutionsFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.accounts, action: \.accounts) {
            AccountsFeature()
        }
        Scope(state: \.creditCards, action: \.creditCards) {
            CreditCardsFeature()
        }
        Scope(state: \.importFeature, action: \.importFeature) {
            ImportFeature()
        }
        Scope(state: \.transactions, action: \.transactions) {
            TransactionsFeature()
        }
        Scope(state: \.categories, action: \.categories) {
            CategoriesFeature()
        }
        Scope(state: \.supportedInstitutions, action: \.supportedInstitutions) {
            SupportedInstitutionsFeature()
        }

        Reduce { _, action in
            switch action {
            case .importFeature(.delegate(.financialDataChanged)):
                return .merge(
                    .send(.accounts(.refresh)),
                    .send(.creditCards(.refresh)),
                    .send(.transactions(.refresh))
                )

            case .transactions(.delegate(.financialDataChanged)):
                return .send(.creditCards(.refresh))

            case .accounts,
                 .creditCards,
                 .importFeature,
                 .transactions,
                 .categories,
                 .supportedInstitutions:
                return .none
            }
        }
    }
}
