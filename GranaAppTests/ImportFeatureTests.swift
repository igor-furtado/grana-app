import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("ImportFeature")
struct ImportFeatureTests {
    @Test("Drop policy aceita o primeiro arquivo suportado quando a importação está ociosa")
    func dropPolicyAcceptsFirstSupportedFile() {
        let first = URL(fileURLWithPath: "/tmp/extrato.ofx")
        let second = URL(fileURLWithPath: "/tmp/fatura.csv")

        let decision = ImportDropPolicy.evaluate(
            urls: [first, second],
            supportedExtensions: ImportFeatureConfiguration.supportedExtensions,
            isImportInProgress: false
        )

        #expect(decision == .accept(first, droppedMultipleFiles: true))
        #expect(decision.acceptsDrop)
    }

    @Test("Drop policy rejeita arquivo não suportado")
    func dropPolicyRejectsUnsupportedFile() {
        let file = URL(fileURLWithPath: "/tmp/extrato.pdf")

        let decision = ImportDropPolicy.evaluate(
            urls: [file],
            supportedExtensions: ImportFeatureConfiguration.supportedExtensions,
            isImportInProgress: false
        )

        #expect(decision == .rejectUnsupported(extensionLabel: "pdf"))
        #expect(!decision.acceptsDrop)
    }

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

    @Test("Drop global abre o wizard com arquivo válido")
    func globalDropStartsWizardFromAnyScreen() async {
        let file = URL(fileURLWithPath: "/tmp/extrato.ofx")
        let store = TestStore(initialState: ImportFeature.State()) {
            ImportFeature()
        }

        await store.send(.globalFileDrop([file])) {
            $0.wizard = ImportWizardFeature.State(initialFile: file)
        }
    }

    @Test("Drop global ignora novo arquivo quando já existe importação em andamento")
    func globalDropKeepsExistingWizardWhenImportInProgress() async {
        let currentFile = URL(fileURLWithPath: "/tmp/atual.ofx")
        let incomingFile = URL(fileURLWithPath: "/tmp/novo.ofx")
        let initialState = ImportFeature.State(
            history: ImportHistoryFeature.State(),
            wizard: ImportWizardFeature.State(initialFile: currentFile)
        )
        let store = TestStore(initialState: initialState) {
            ImportFeature()
        } withDependencies: {
            $0.noticeClient.info = { _, _ in }
        }

        await store.send(.globalFileDrop([incomingFile]))
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

    @Test("CSV conta reembolso vinculado apenas quando estiver selecionado")
    func csvResolutionCountsOnlySelectedRefunds() {
        let skipped = InterCreditCardCSVReader.SkippedRow(
            date: Date(),
            description: "ESTORNO",
            amount: -10,
            kind: .refund
        )
        let resolution = CSVStatementResolution(
            sourceFilename: "fatura.csv",
            accountId: UUID(),
            rows: [],
            negativeRows: [
                CSVNegativePreviewRow(raw: skipped, purchaseId: UUID(), selected: true),
                CSVNegativePreviewRow(raw: skipped, purchaseId: UUID(), selected: false),
            ]
        )

        #expect(resolution.selectedCount == 1)
    }
}
