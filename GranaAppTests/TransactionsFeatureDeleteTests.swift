import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("TransactionsFeature delete")
struct TransactionsFeatureDeleteTests {
    @Test("Confirmar exclusão apaga, recarrega e notifica sucesso")
    func deleteConfirmationDeletesRefreshesAndNotifies() async {
        let data = makeDeleteFixture()
        let snapshot = makeDeleteSnapshot(
            page: TransactionRemotePage(transactions: [data.transaction], nextCursor: nil),
            accounts: [data.account],
            institutions: [data.institution],
            categories: [data.category]
        )
        let refreshed = makeDeleteSnapshot(
            accounts: [data.account],
            institutions: [data.institution],
            categories: [data.category]
        )
        let recorder = DeleteRecorder()
        let notices = LockIsolated<[(String, String?)]>([])
        var initialState = TransactionsFeature.State()
        initialState.apply(snapshot)
        initialState.hasLoaded = true
        let store = TestStore(initialState: initialState) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionsClient = TransactionsClient(
                loadSnapshot: { _ in refreshed },
                create: { _ in },
                update: { _, _ in },
                delete: { id in await recorder.record(id) }
            )
            $0.noticeClient.report = { _, _ in }
            $0.noticeClient.success = { title, message in
                notices.withValue { $0.append((title, message)) }
            }
        }

        await store.send(.deleteButtonTapped(data.transaction)) {
            $0.pendingDelete = data.transaction
        }
        await store.send(.deleteConfirmedButtonTapped) {
            $0.pendingDelete = nil
        }
        await store.receive(\.snapshotLoaded) {
            $0.apply(refreshed)
            $0.hasLoaded = true
        }

        #expect(await recorder.deletedIds() == [data.transaction.id])
        #expect(notices.value.count == 1)
        #expect(notices.value.first?.0 == "Transação apagada")
        #expect(notices.value.first?.1 == nil)
    }

    @Test("Falha no refresh após exclusão não reporta falha ao apagar")
    func deleteConfirmationSeparatesRefreshFailureFromDeleteFailure() async {
        let data = makeDeleteFixture()
        let snapshot = makeDeleteSnapshot(
            page: TransactionRemotePage(transactions: [data.transaction], nextCursor: nil),
            accounts: [data.account],
            institutions: [data.institution],
            categories: [data.category]
        )
        let recorder = DeleteRecorder()
        let successNotices = LockIsolated<[(String, String?)]>([])
        let errorNotices = LockIsolated<[String?]>([])
        var initialState = TransactionsFeature.State()
        initialState.apply(snapshot)
        initialState.hasLoaded = true
        let store = TestStore(initialState: initialState) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionsClient = TransactionsClient(
                loadSnapshot: { _ in throw NSError(domain: "Refresh", code: 1) },
                create: { _ in },
                update: { _, _ in },
                delete: { id in await recorder.record(id) }
            )
            $0.noticeClient.report = { _, title in
                errorNotices.withValue { $0.append(title) }
            }
            $0.noticeClient.success = { title, message in
                successNotices.withValue { $0.append((title, message)) }
            }
        }

        await store.send(.deleteButtonTapped(data.transaction)) {
            $0.pendingDelete = data.transaction
        }
        await store.send(.deleteConfirmedButtonTapped) {
            $0.pendingDelete = nil
        }
        await store.receive(\.deleteRefreshFailed)

        #expect(await recorder.deletedIds() == [data.transaction.id])
        #expect(successNotices.value.first?.0 == "Transação apagada")
        #expect(errorNotices.value == ["Transação apagada, mas falha ao atualizar lista"])
    }
}

private actor DeleteRecorder {
    private var recordedIds: [UUID] = []

    func record(_ id: UUID) {
        recordedIds.append(id)
    }

    func deletedIds() -> [UUID] {
        recordedIds
    }
}

private func makeDeleteFixture() -> (
    institution: Institution,
    category: GranaApp.Category,
    account: Account,
    transaction: Transaction
) {
    let institution = Institution(
        id: UUID(),
        code: "077",
        name: "Banco Inter",
        kind: .inter,
        capabilities: InstitutionCapabilities(
            supportedAccountTypes: [.checking],
            supportedImportFormats: []
        ),
        createdAt: Date(),
        updatedAt: Date()
    )
    let category = GranaApp.Category(
        id: UUID(),
        parentId: nil,
        name: "Restaurantes",
        kind: .expense,
        slug: "alimentacao",
        createdAt: Date()
    )
    let account = Account(
        id: UUID(),
        type: .checking,
        initialBalance: 300,
        archived: false,
        institutionId: institution.id,
        currency: "BRL",
        createdAt: Date(),
        updatedAt: Date()
    )
    let transaction = Transaction(
        id: UUID(),
        accountId: account.id,
        categoryId: category.id,
        subcategoryId: nil,
        amount: 42,
        occurredAt: Date(),
        description: "Transação",
        notes: nil,
        destinationAccountId: nil,
        refundOfTransactionId: nil,
        createdAt: Date().addingTimeInterval(-5),
        updatedAt: Date().addingTimeInterval(-5)
    )
    return (institution, category, account, transaction)
}

private func makeDeleteSnapshot(
    page: TransactionRemotePage = .empty,
    accounts: [Account] = [],
    institutions: [Institution] = [],
    categories: [GranaApp.Category] = []
) -> TransactionsSnapshot {
    TransactionsSnapshot(
        page: page,
        accounts: accounts,
        institutions: institutions,
        bankDetails: accounts.map { account in
            BankAccountDetails(
                accountId: account.id,
                branchId: "0001",
                accountNumber: "1234",
                createdAt: account.createdAt,
                updatedAt: account.updatedAt
            )
        },
        creditCards: [],
        categories: categories,
        statements: [],
        statementPayments: []
    )
}
