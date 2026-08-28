import Foundation
@testable import GranaApp

func statementDateEditorScenario() -> (
    card: CreditCardListItem,
    statement: Statement,
    updated: Statement,
    result: StatementDateUpdateResult
) {
    let card = CreditCardListItem(
        account: .fixture(id: UUID(), institutionId: UUID(), archived: false),
        institution: nil,
        details: .fixture(accountId: UUID(), last4: "1234"),
        currentBalance: 300
    )
    let statement = Statement(
        id: UUID(),
        accountId: card.id,
        closingDate: Date(timeIntervalSince1970: 1_695_556_800),
        dueDate: Date(timeIntervalSince1970: 1_696_248_000),
        netAmount: 300,
        creditReceived: 0,
        paymentApplied: 0,
        settledAt: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
    let updated = Statement(
        id: statement.id,
        accountId: card.id,
        closingDate: Date(timeIntervalSince1970: 1_695_470_400),
        dueDate: Date(timeIntervalSince1970: 1_696_334_400),
        netAmount: 300,
        creditReceived: 0,
        paymentApplied: 0,
        settledAt: nil,
        createdAt: statement.createdAt,
        updatedAt: Date()
    )
    return (
        card: card,
        statement: statement,
        updated: updated,
        result: StatementDateUpdateResult(
            statementId: statement.id,
            movedTransactionCount: 2,
            enteredTransactionCount: 1,
            exitedTransactionCount: 0,
            affectedStatementCount: 2,
            paymentDifferenceStatementCount: 1
        )
    )
}

extension Account {
    static func fixture(id: UUID, institutionId: UUID, archived: Bool) -> Account {
        Account(
            id: id,
            type: .creditCard,
            initialBalance: 0,
            archived: archived,
            institutionId: institutionId,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

extension Institution {
    static func fixture(
        id: UUID = UUID(),
        name: String = "Inter"
    ) -> Institution {
        Institution(
            id: id,
            code: "077",
            name: name,
            kind: .inter,
            capabilities: InstitutionCapabilities(
                supportedAccountTypes: [.creditCard],
                supportedImportFormats: [.ofx]
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

extension CreditCardDetails {
    static func fixture(accountId: UUID, last4: String) -> CreditCardDetails {
        CreditCardDetails(
            accountId: accountId,
            cardLastFour: last4,
            creditLimit: 1000,
            statementClosingDay: 10,
            paymentDueDay: 20,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
