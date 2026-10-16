import ComposableArchitecture
import Foundation

struct ImportHistoryClient {
    var loadSnapshot: @Sendable () async throws -> ImportSnapshot
    var undo: @Sendable (_ batchId: UUID) async throws -> Void

    static func live(container: AppContainer) -> ImportHistoryClient {
        ImportHistoryClient(
            loadSnapshot: {
                try await ImportHistoryLoading.loadSnapshot(container: container)
            },
            undo: { batchId in
                try await container.remoteImports.delete(batchId: batchId)
            }
        )
    }
}

extension ImportHistoryClient: DependencyKey {
    static let liveValue = ImportHistoryClient(
        loadSnapshot: { .empty },
        undo: { _ in }
    )

    static let testValue = ImportHistoryClient(
        loadSnapshot: unimplemented("ImportHistoryClient.loadSnapshot"),
        undo: unimplemented("ImportHistoryClient.undo")
    )
}

extension DependencyValues {
    var importHistoryClient: ImportHistoryClient {
        get { self[ImportHistoryClient.self] }
        set { self[ImportHistoryClient.self] = newValue }
    }
}

enum ImportHistoryLoading {
    static func loadSnapshot(container: AppContainer) async throws -> ImportSnapshot {
        async let institutionsTask = container.institutionCatalog.load()
        async let categoriesTask = container.categoryCatalog.load()
        async let accountsTask = container.remoteAccounts.load()
        async let batchesTask = container.remoteImports.loadBatches()
        let (institutions, categories, accountSnapshot, batches) = try await (
            institutionsTask,
            categoriesTask,
            accountsTask,
            batchesTask
        )
        return ImportSnapshot(
            batches: batches,
            accounts: accountSnapshot.accounts,
            institutions: institutions,
            bankDetails: accountSnapshot.bankDetails,
            creditCards: accountSnapshot.creditCards,
            categories: categories
        )
    }
}
