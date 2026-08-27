import ComposableArchitecture
import Foundation

@Reducer
struct CreditCardFormFeature {
    @ObservableState
    struct State: Equatable {
        var existingCard: CreditCardListItem?
        var institutions: [Institution]
        var calendar: Calendar = .current
        var referenceDate: Date = .init()
        var institutionId: UUID?
        var currency = "BRL"
        var cardLastFour = ""
        var creditLimitCents = 0
        var hasCreditLimit = false
        var statementClosingDay = 1
        var paymentDueDay = 10
        var saveError: String?
        var isSaving = false

        init(
            existingCard: CreditCardListItem? = nil,
            institutions: [Institution]
        ) {
            self.existingCard = existingCard
            self.institutions = institutions

            if let existingCard {
                self.institutionId = existingCard.account.institutionId
                self.currency = existingCard.account.currency
                self.cardLastFour = existingCard.details?.cardLastFour ?? ""
                self.statementClosingDay = existingCard.details?.statementClosingDay ?? 1
                self.paymentDueDay = existingCard.details?.paymentDueDay ?? 10
                if let creditLimit = existingCard.details?.creditLimit {
                    self.hasCreditLimit = true
                    self.creditLimitCents = Int(truncatingIfNeeded: Converters.decimalToCents(creditLimit))
                }
            } else {
                self.institutionId = availableInstitutions.first?.id
            }
        }

        var availableInstitutions: [Institution] {
            institutions.filter { $0.capabilities.supportedAccountTypes.contains(.creditCard) }
        }

        var navigationTitle: String {
            existingCard == nil ? "Novo cartão" : "Editar cartão"
        }

        var canSave: Bool {
            institutionId != nil && cardLastFour.count == 4
        }

        var isCardLastFourPartial: Bool {
            !cardLastFour.isEmpty && cardLastFour.count != 4
        }

        var cycleConfigurationChanged: Bool {
            guard let details = existingCard?.details else { return false }
            return details.statementClosingDay != statementClosingDay
                || details.paymentDueDay != paymentDueDay
        }

        var cycleEffectiveFrom: Date? {
            nil
        }

        func mutationInput() -> CreditCardMutationInput? {
            guard let institutionId, cardLastFour.count == 4 else { return nil }
            return CreditCardMutationInput(
                institutionId: institutionId,
                currency: currency,
                cardLastFour: cardLastFour,
                creditLimit: hasCreditLimit ? Decimal(creditLimitCents) / 100 : nil,
                statementClosingDay: statementClosingDay,
                paymentDueDay: paymentDueDay
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

    @Dependency(\.creditCardsClient) private var creditCardsClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.cardLastFour):
                let digits = state.cardLastFour.filter(\.isNumber)
                state.cardLastFour = String(digits.prefix(4))
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
        return .run { [existingCard = state.existingCard, cycleEffectiveFrom = state.cycleEffectiveFrom] send in
            do {
                if let existingCard {
                    try await creditCardsClient.update(
                        existingCard.id,
                        existingCard.account.archived,
                        input,
                        cycleEffectiveFrom
                    )
                } else {
                    try await creditCardsClient.create(input)
                }
                await send(.saveSucceeded)
            } catch {
                await noticeClient.report(error, "Falha ao salvar cartão")
                await send(.saveFailed(error.localizedDescription))
            }
        }
    }
}
