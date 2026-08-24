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
                        dueDate: now.addingTimeInterval(86_400 * 10),
                        netAmountCents: 12_345,
                        creditReceivedCents: 2_000,
                        paymentAppliedCents: 3_000,
                        settledAt: now.addingTimeInterval(86_400),
                        createdAt: now.addingTimeInterval(-86_400),
                        updatedAt: now
                    ),
                ],
                payments: [
                    StatementPaymentRecordRow(
                        id: UUID(),
                        statementId: statementId,
                        transactionId: transactionId,
                        appliedAmountCents: 3_000,
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
                            amountCents: 9_876,
                            occurredAt: now,
                            description: "Mercado",
                            notes: "Compra",
                            importBatchId: nil,
                            externalId: nil,
                            destinationAccountId: nil,
                            statementId: statementId,
                            refundOfTransactionId: nil,
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
}

private actor FakeStatementRemoteStore: StatementRemoteStore {
    let statements: [StatementRecordRow]
    let payments: [StatementPaymentRecordRow]
    let transactionsByStatementId: [UUID: [TransactionRecordRow]]

    init(
        statements: [StatementRecordRow] = [],
        payments: [StatementPaymentRecordRow] = [],
        transactionsByStatementId: [UUID: [TransactionRecordRow]] = [:]
    ) {
        self.statements = statements
        self.payments = payments
        self.transactionsByStatementId = transactionsByStatementId
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
}
