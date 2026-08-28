import ComposableArchitecture
import Foundation

@Reducer
struct StatementDateEditorFeature {
    @ObservableState
    struct State: Equatable {
        let statementId: UUID
        let title: String
        var closingDate: Date
        var dueDate: Date
        let previousClosingDate: Date?
        let nextClosingDate: Date?
        var isSaving = false

        var canSave: Bool {
            guard dueDate > closingDate else { return false }
            if let previousClosingDate, closingDate <= previousClosingDate {
                return false
            }
            if let nextClosingDate, closingDate >= nextClosingDate {
                return false
            }
            return true
        }

        var validationMessage: String? {
            guard dueDate > closingDate else {
                return "A data de vencimento precisa ser posterior ao fechamento."
            }
            if let previousClosingDate, closingDate <= previousClosingDate {
                return "O fechamento precisa ficar depois da fatura anterior."
            }
            if let nextClosingDate, closingDate >= nextClosingDate {
                return "O fechamento precisa ficar antes da próxima fatura."
            }
            return nil
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case cancelButtonTapped
        case saveButtonTapped
        case saveSucceeded(StatementDateUpdateResult)
        case saveFailed
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case cancel
        case saved(StatementDateUpdateResult)
    }

    @Dependency(\.creditCardsClient) private var creditCardsClient
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
                guard state.canSave else {
                    let message = state.validationMessage
                    return .run { _ in
                        await noticeClient.info("Revise as datas da fatura", message)
                    }
                }
                state.isSaving = true
                let statementId = state.statementId
                let closingDate = state.closingDate
                let dueDate = state.dueDate
                return .run { send in
                    do {
                        let result = try await creditCardsClient.updateStatementDates(
                            statementId,
                            closingDate,
                            dueDate
                        )
                        await noticeClient.info(
                            "Datas da fatura atualizadas",
                            Self.successMessage(for: result)
                        )
                        await send(.saveSucceeded(result))
                    } catch {
                        await noticeClient.report(error, "Falha ao salvar datas da fatura")
                        await send(.saveFailed)
                    }
                }

            case let .saveSucceeded(result):
                state.isSaving = false
                return .send(.delegate(.saved(result)))

            case .saveFailed:
                state.isSaving = false
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private static func successMessage(for result: StatementDateUpdateResult) -> String {
        let moved = result.movedTransactionCount
        let transactionText = moved == 1
            ? "1 transação foi realocada."
            : "\(moved) transações foram realocadas."
        guard result.paymentDifferenceStatementCount > 0 else {
            return transactionText
        }
        let differenceText = result.paymentDifferenceStatementCount == 1
            ? " 1 fatura ficou com diferença de pagamento visível."
            : " \(result.paymentDifferenceStatementCount) faturas ficaram com diferença de pagamento visível."
        return transactionText + differenceText
    }
}
