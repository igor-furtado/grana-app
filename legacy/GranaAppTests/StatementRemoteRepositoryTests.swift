import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("StatementRemoteRepository")
struct StatementRemoteRepositoryTests {
    @Test("Mapeia snapshot remoto de faturas e pagamentos")
    func mapsStatementSnapshot() async throws {
        let now = Date()
        let statementId = UUID()
        let transactionId = UUID()
        let accountId = UUID()
        let repository = StatementRemoteRepository(
            remoteStore: FakeStatementRemoteStore(
                statements: [
                    StatementRecordRow(
                        id: statementId,
                        accountId: accountId,
                        closingDate: now,
                        dueDate: now.addingTimeInterval(86400 * 10),
                        netAmountCents: 12345,
                        creditReceivedCents: 2000,
                        paymentAppliedCents: 3000,
                        settledAt: now.addingTimeInterval(86400),
                        createdAt: now.addingTimeInterval(-86400),
                        updatedAt: now
                    ),
                ],
                payments: [
                    StatementPaymentRecordRow(
                        id: UUID(),
                        statementId: statementId,
                        transactionId: transactionId,
                        appliedAmountCents: 3000,
                        createdAt: now,
                        updatedAt: now
                    ),
                ]
            )
        )

        let snapshot = try await repository.load()

        #expect(snapshot.statements.count == 1)
        #expect(snapshot.statements.first?.netAmount == Decimal(string: "123.45"))
        #expect(snapshot.statements.first?.creditReceived == 20)
        #expect(snapshot.statements.first?.paymentApplied == 30)
        #expect(snapshot.payments.first?.transactionId == transactionId)
    }

    @Test("Mapeia lançamentos remotos de uma fatura")
    func mapsStatementTransactions() async throws {
        let now = Date()
        let statementId = UUID()
        let transactionId = UUID()
        let accountId = UUID()
        let categoryId = UUID()
        let repository = StatementRemoteRepository(
            remoteStore: FakeStatementRemoteStore(
                transactionsByStatementId: [
                    statementId: [
                        TransactionRecordRow(
                            id: transactionId,
                            accountId: accountId,
                            categoryId: categoryId,
                            subcategoryId: nil,
                            amountCents: 9876,
                            occurredAt: now,
                            description: "Mercado",
                            notes: "Compra",
                            importBatchId: nil,
                            externalId: nil,
                            destinationAccountId: nil,
                            statementId: statementId,
                            createdAt: now.addingTimeInterval(-60),
                            updatedAt: now
                        ),
                    ],
                ]
            )
        )

        let transactions = try await repository.loadTransactions(statementId: statementId)

        #expect(transactions.map(\.id) == [transactionId])
        #expect(transactions.first?.statementId == statementId)
        #expect(transactions.first?.amount == Decimal(string: "98.76"))
    }

    @Test("Mapeia resultado de edição de datas da fatura")
    func mapsStatementDateUpdateResult() async throws {
        let statementId = UUID()
        let repository = StatementRemoteRepository(
            remoteStore: FakeStatementRemoteStore(
                dateUpdateResponse: StatementDateUpdateResponse(
                    ok: true,
                    code: nil,
                    statementId: statementId,
                    movedTransactionCount: 12,
                    enteredTransactionCount: 5,
                    exitedTransactionCount: 7,
                    affectedStatementCount: 3,
                    paymentDifferenceStatementCount: 1
                )
            )
        )

        let result = try await repository.updateDates(
            statementId: statementId,
            closingDate: Date(),
            dueDate: Date()
        )

        #expect(result.statementId == statementId)
        #expect(result.movedTransactionCount == 12)
        #expect(result.enteredTransactionCount == 5)
        #expect(result.exitedTransactionCount == 7)
        #expect(result.affectedStatementCount == 3)
        #expect(result.paymentDifferenceStatementCount == 1)
    }

    @Test("Mapeia erro estável de datas inválidas")
    func mapsInvalidStatementDatesError() async {
        let repository = StatementRemoteRepository(
            remoteStore: FakeStatementRemoteStore(
                dateUpdateResponse: StatementDateUpdateResponse(
                    ok: false,
                    code: "invalid_statement_dates",
                    statementId: nil,
                    movedTransactionCount: nil,
                    enteredTransactionCount: nil,
                    exitedTransactionCount: nil,
                    affectedStatementCount: nil,
                    paymentDifferenceStatementCount: nil
                )
            )
        )

        await #expect(throws: StatementRemoteRepositoryError.invalidStatementDates) {
            try await repository.updateDates(
                statementId: UUID(),
                closingDate: Date(),
                dueDate: Date()
            )
        }
    }
}

private actor FakeStatementRemoteStore: StatementRemoteStore {
    let statements: [StatementRecordRow]
    let payments: [StatementPaymentRecordRow]
    let transactionsByStatementId: [UUID: [TransactionRecordRow]]
    let dateUpdateResponse: StatementDateUpdateResponse

    init(
        statements: [StatementRecordRow] = [],
        payments: [StatementPaymentRecordRow] = [],
        transactionsByStatementId: [UUID: [TransactionRecordRow]] = [:],
        dateUpdateResponse: StatementDateUpdateResponse = StatementDateUpdateResponse(
            ok: true,
            code: nil,
            statementId: UUID(),
            movedTransactionCount: 0,
            enteredTransactionCount: 0,
            exitedTransactionCount: 0,
            affectedStatementCount: 0,
            paymentDifferenceStatementCount: 0
        )
    ) {
        self.statements = statements
        self.payments = payments
        self.transactionsByStatementId = transactionsByStatementId
        self.dateUpdateResponse = dateUpdateResponse
    }

    func fetchStatements() async throws -> [StatementRecordRow] {
        statements
    }

    func fetchStatementPayments() async throws -> [StatementPaymentRecordRow] {
        payments
    }

    func fetchTransactions(statementId: UUID) async throws -> [TransactionRecordRow] {
        transactionsByStatementId[statementId] ?? []
    }

    func updateStatementDates(request _: UpdateStatementDatesRequest) async throws -> StatementDateUpdateResponse {
        dateUpdateResponse
    }
}
