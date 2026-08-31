import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("TransactionRemoteRepository")
struct TransactionRemoteRepositoryTests {
    @Test("Mapeia página remota e cursor estável")
    func mapsPageAndCursor() async throws {
        let now = Date()
        let firstId = UUID()
        let secondId = UUID()
        let thirdId = UUID()
        let accountId = UUID()
        let categoryId = UUID()
        let repository = TransactionRemoteRepository(
            remoteStore: FakeTransactionRemoteStore(rows: [
                makeTransactionRecordRow(
                    id: firstId,
                    accountId: accountId,
                    categoryId: categoryId,
                    amountCents: 12345,
                    occurredAt: now,
                    createdAt: now.addingTimeInterval(-10)
                ),
                makeTransactionRecordRow(
                    id: secondId,
                    accountId: accountId,
                    categoryId: categoryId,
                    amountCents: 6789,
                    occurredAt: now.addingTimeInterval(-60),
                    createdAt: now.addingTimeInterval(-70)
                ),
                makeTransactionRecordRow(
                    id: thirdId,
                    accountId: accountId,
                    categoryId: categoryId,
                    amountCents: 500,
                    occurredAt: now.addingTimeInterval(-120),
                    createdAt: now.addingTimeInterval(-130)
                ),
            ])
        )

        let page = try await repository.loadPage(cursor: nil, limit: 2)

        #expect(page.transactions.map(\.id) == [firstId, secondId])
        #expect(page.transactions.first?.amount == Decimal(string: "123.45"))
        #expect(
            page.nextCursor == TransactionRemotePageCursor(
                occurredAt: now.addingTimeInterval(-60),
                createdAt: now.addingTimeInterval(-70),
                id: secondId
            )
        )
    }

    @Test("Mapeia erro estável de transferência inválida")
    func mapsInvalidTransferDestinationCode() async {
        let repository = TransactionRemoteRepository(
            remoteStore: FakeTransactionRemoteStore(
                createResponse: .init(ok: false, code: "invalid_transfer_destination", transactionId: nil)
            )
        )

        await #expect(throws: TransactionRemoteRepositoryError.invalidTransferDestination) {
            try await repository.create(input: makeTransactionMutationInput())
        }
    }

    @Test("Mapeia erro estável de pagamento")
    func mapsCardRuleCodes() async {
        let unappliedPayment = TransactionRemoteRepository(
            remoteStore: FakeTransactionRemoteStore(
                createResponse: .init(ok: false, code: "unapplied_payment", transactionId: nil)
            )
        )

        await #expect(throws: TransactionRemoteRepositoryError.unappliedPayment) {
            try await unappliedPayment.create(input: makeTransactionMutationInput())
        }
    }

    @Test("Converte Decimal em centavos nas mutações")
    func mapsDecimalToCentsInMutationRequests() {
        let input = TransactionMutationInput(
            accountId: UUID(),
            categoryId: UUID(),
            subcategoryId: nil,
            amount: Decimal(string: "123.45") ?? 0,
            occurredAt: Date(),
            originOccurredAt: Date().addingTimeInterval(-86_400),
            purchaseType: .installment,
            installmentIndex: 2,
            installmentCount: 5,
            description: "Mercado",
            notes: "Sem observações",
            destinationAccountId: nil
        )

        let createRequest = CreateTransactionRequest(input: input)
        let updateRequest = UpdateTransactionRequest(
            transactionId: UUID(),
            input: input
        )

        #expect(createRequest.pAmountCents == 12345)
        #expect(updateRequest.pAmountCents == 12345)
        #expect(createRequest.pPurchaseType == "installment")
        #expect(createRequest.pInstallmentIndex == 2)
        #expect(createRequest.pInstallmentCount == 5)
        #expect(updateRequest.pPurchaseType == "installment")
        #expect(updateRequest.pInstallmentIndex == 2)
        #expect(updateRequest.pInstallmentCount == 5)
    }

    @Test("Payload de create preserva parâmetros opcionais nulos para RPC")
    func createPayloadKeepsNullOptionalRPCParameters() throws {
        let request = CreateTransactionRequest(input: makeTransactionMutationInput())

        let payload = try rpcPayload(from: request)

        #expect(payload["p_subcategory_id"] is NSNull)
        #expect(payload["p_notes"] is NSNull)
        #expect(payload["p_purchase_type"] is NSNull)
        #expect(payload["p_installment_index"] is NSNull)
        #expect(payload["p_installment_count"] is NSNull)
        #expect(payload["p_destination_account_id"] is NSNull)
    }

    @Test("Payload de update preserva parâmetros opcionais nulos para RPC")
    func updatePayloadKeepsNullOptionalRPCParameters() throws {
        let request = UpdateTransactionRequest(
            transactionId: UUID(),
            input: makeTransactionMutationInput()
        )

        let payload = try rpcPayload(from: request)

        #expect(payload["p_subcategory_id"] is NSNull)
        #expect(payload["p_notes"] is NSNull)
        #expect(payload["p_purchase_type"] is NSNull)
        #expect(payload["p_installment_index"] is NSNull)
        #expect(payload["p_installment_count"] is NSNull)
        #expect(payload["p_destination_account_id"] is NSNull)
    }
}

private actor FakeTransactionRemoteStore: TransactionRemoteStore {
    let rows: [TransactionRecordRow]
    let createResponse: TransactionMutationResponse
    let updateResponse: TransactionMutationResponse
    let deleteResponse: TransactionMutationResponse

    init(
        rows: [TransactionRecordRow] = [],
        createResponse: TransactionMutationResponse = .init(ok: true, code: nil, transactionId: UUID()),
        updateResponse: TransactionMutationResponse = .init(ok: true, code: nil, transactionId: nil),
        deleteResponse: TransactionMutationResponse = .init(ok: true, code: nil, transactionId: nil)
    ) {
        self.rows = rows
        self.createResponse = createResponse
        self.updateResponse = updateResponse
        self.deleteResponse = deleteResponse
    }

    func fetchTransactions(request _: ListTransactionsRequest) async throws -> [TransactionRecordRow] {
        rows
    }

    func createTransaction(request _: CreateTransactionRequest) async throws -> TransactionMutationResponse {
        createResponse
    }

    func updateTransaction(request _: UpdateTransactionRequest) async throws -> TransactionMutationResponse {
        updateResponse
    }

    func deleteTransaction(request _: DeleteTransactionRequest) async throws -> TransactionMutationResponse {
        deleteResponse
    }
}

private actor SequencedTransactionRemoteRepository: TransactionRemoteRepositoryProtocol {
    struct Operation: Equatable {
        enum Kind: Equatable {
            case create
            case update
            case delete
        }

        let kind: Kind
        let transactionId: UUID?
        let input: TransactionMutationInput?
    }

    private var pages: [TransactionRemotePage]
    private var recordedOperations: [Operation] = []
    private var cursors: [TransactionRemotePageCursor?] = []
    private var loads = 0

    init(pages: [TransactionRemotePage]) {
        self.pages = pages
    }

    func loadPage(cursor: TransactionRemotePageCursor?, limit _: Int) async throws -> TransactionRemotePage {
        loads += 1
        cursors.append(cursor)
        if pages.count > 1 {
            return pages.removeFirst()
        }
        return pages.first ?? .empty
    }

    func create(input: TransactionMutationInput) async throws {
        recordedOperations.append(.init(kind: .create, transactionId: nil, input: input))
    }

    func update(transactionId: UUID, input: TransactionMutationInput) async throws {
        recordedOperations.append(.init(kind: .update, transactionId: transactionId, input: input))
    }

    func delete(transactionId: UUID) async throws {
        recordedOperations.append(.init(kind: .delete, transactionId: transactionId, input: nil))
    }

    func operations() -> [Operation] {
        recordedOperations
    }

    func requestedCursors() -> [TransactionRemotePageCursor?] {
        cursors
    }

    func loadCallCount() -> Int {
        loads
    }
}

private struct FailingTransactionRemoteRepository: TransactionRemoteRepositoryProtocol {
    let error: any Error

    func loadPage(cursor _: TransactionRemotePageCursor?, limit _: Int) async throws -> TransactionRemotePage {
        .empty
    }

    func create(input _: TransactionMutationInput) async throws {
        throw error
    }

    func update(transactionId _: UUID, input _: TransactionMutationInput) async throws {
        throw error
    }

    func delete(transactionId _: UUID) async throws {
        throw error
    }
}

private actor RefreshFailingAfterMutationRepository: TransactionRemoteRepositoryProtocol {
    private let initialPage: TransactionRemotePage
    private let refreshError: TransactionRemoteRepositoryError
    private var loadCalls = 0

    init(
        initialPage: TransactionRemotePage,
        refreshError: TransactionRemoteRepositoryError
    ) {
        self.initialPage = initialPage
        self.refreshError = refreshError
    }

    func loadPage(cursor _: TransactionRemotePageCursor?, limit _: Int) async throws -> TransactionRemotePage {
        defer { loadCalls += 1 }
        if loadCalls == 0 {
            return initialPage
        }
        throw refreshError
    }

    func create(input _: TransactionMutationInput) async throws {}

    func update(transactionId _: UUID, input _: TransactionMutationInput) async throws {}

    func delete(transactionId _: UUID) async throws {}
}

private actor SequencedStatementRemoteRepository: StatementRemoteRepositoryProtocol {
    private var snapshots: [StatementRemoteSnapshot]

    init(snapshots: [StatementRemoteSnapshot]) {
        self.snapshots = snapshots
    }

    func load() async throws -> StatementRemoteSnapshot {
        if snapshots.count > 1 {
            return snapshots.removeFirst()
        }
        return snapshots.first ?? .empty
    }

    func loadTransactions(statementId _: UUID) async throws -> [Transaction] {
        []
    }

    func updateDates(
        statementId: UUID,
        closingDate _: Date,
        dueDate _: Date
    ) async throws -> StatementDateUpdateResult {
        StatementDateUpdateResult(
            statementId: statementId,
            movedTransactionCount: 0,
            enteredTransactionCount: 0,
            exitedTransactionCount: 0,
            affectedStatementCount: 0,
            paymentDifferenceStatementCount: 0
        )
    }
}

private func makeTransactionRecordRow(
    id: UUID,
    accountId: UUID,
    categoryId: UUID,
    amountCents: Int64,
    occurredAt: Date,
    createdAt: Date,
    updatedAt: Date? = nil
) -> TransactionRecordRow {
    TransactionRecordRow(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        subcategoryId: nil,
        amountCents: amountCents,
        occurredAt: occurredAt,
        originOccurredAt: occurredAt,
        purchaseType: nil,
        installmentIndex: nil,
        installmentCount: nil,
        description: "Item \(id.uuidString.prefix(4))",
        notes: nil,
        importBatchId: nil,
        externalId: nil,
        destinationAccountId: nil,
        statementId: nil,
        createdAt: createdAt,
        updatedAt: updatedAt ?? createdAt
    )
}

private func makeTransactionMutationInput(
    destinationAccountId: UUID? = nil
) -> TransactionMutationInput {
    TransactionMutationInput(
        accountId: UUID(),
        categoryId: UUID(),
        subcategoryId: nil,
        amount: 100,
        occurredAt: Date(),
        description: "Almoço",
        notes: nil,
        destinationAccountId: destinationAccountId
    )
}

private func rpcPayload<Request: Encodable>(from request: Request) throws -> [String: Any] {
    let data = try JSONEncoder().encode(request)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
