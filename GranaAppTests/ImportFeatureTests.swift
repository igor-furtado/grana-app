import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("ImportFeature")
struct ImportFeatureTests {
    @Test("Histórico carrega snapshot pelo client dedicado")
    func historyLoadsSnapshotFromClient() async {
        let snapshot = ImportSnapshot(
            batches: [],
            accounts: [],
            institutions: [],
            bankDetails: [],
            creditCards: [],
            categories: []
        )
        let store = TestStore(initialState: ImportHistoryFeature.State()) {
            ImportHistoryFeature()
        } withDependencies: {
            $0.importClient.loadSnapshot = { snapshot }
        }

        await store.send(.task) {
            $0.isLoading = true
        }

        await store.receive(.snapshotLoaded(.success(snapshot))) {
            $0.snapshot = snapshot
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    @Test("Builder usa fallback não classificado quando revisão não escolhe categoria")
    func commitBuilderFallsBackToUnclassified() throws {
        let fallback = Category(
            id: UUID(),
            parentId: nil,
            name: "Não Classificado",
            kind: CategoryKind.expense,
            slug: "nao-classificado",
            createdAt: Date()
        )
        let batchId = UUID()
        let input = try ImportCommitBuilder.buildInput(
            idempotencyKey: UUID(),
            reviewedRows: [
                ReviewedImportRow(
                    draft: TransactionDraft(
                        id: UUID(),
                        accountId: UUID(),
                        importBatchId: batchId,
                        signedAmount: Decimal(string: "-12.34") ?? 0,
                        occurredAt: Date(),
                        description: "Padaria",
                        notes: nil,
                        externalId: "FIT-1"
                    ),
                    categoryId: nil,
                    subcategoryId: nil
                ),
            ],
            pendingBatches: [
                PendingImportBatch(
                    batch: ImportBatch(
                        id: batchId,
                        sourceFilename: "extrato.ofx",
                        accountId: UUID(),
                        rowCount: 1,
                        importedAt: Date(),
                        createdAt: Date(),
                        updatedAt: Date()
                    ),
                    importFormat: .ofx
                ),
            ],
            categories: [fallback]
        )

        #expect(input.rows.count == 1)
        #expect(input.rows.first?.categorySlug == "nao-classificado")
        #expect(input.rows.first?.amount == Decimal(string: "12.34"))
    }
}
