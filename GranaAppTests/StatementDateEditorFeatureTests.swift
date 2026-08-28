import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("StatementDateEditorFeature")
struct StatementDateEditorFeatureTests {
    @Test("Datas inválidas da fatura mostram aviso sem chamar backend")
    func statementDateEditorInvalidDatesShowsNotice() async {
        let scenario = statementDateEditorScenario()
        let notices = LockIsolated<[(String, String?)]>([])
        let store = TestStore(
            initialState: StatementDateEditorFeature.State(
                statementId: scenario.statement.id,
                title: "Outubro/2023",
                closingDate: scenario.statement.closingDate,
                dueDate: scenario.statement.closingDate,
                previousClosingDate: nil,
                nextClosingDate: nil
            )
        ) {
            StatementDateEditorFeature()
        } withDependencies: {
            $0.noticeClient.info = { title, message in
                notices.withValue { $0.append((title, message)) }
            }
        }

        await store.send(.saveButtonTapped)

        #expect(notices.value.count == 1)
        #expect(notices.value.first?.0 == "Revise as datas da fatura")
        #expect(notices.value.first?.1 == "A data de vencimento precisa ser posterior ao fechamento.")
    }
}
