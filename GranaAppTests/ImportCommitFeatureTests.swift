import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("ImportCommitFeature")
struct ImportCommitFeatureTests {
    @Test("Commit executa client e delega conclusão")
    func commitRunsClientAndDelegatesCompletion() async throws {
        let batchId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000301"))
        let result = ImportCommitResult(
            batchIds: [batchId],
            importedRowCount: 2,
            duplicateRows: []
        )
        let commit = makeCommit()
        var recordedCommit: ReviewedImportCommit?
        let store = TestStore(initialState: ImportCommitFeature.State(commit: commit)) {
            ImportCommitFeature()
        } withDependencies: {
            $0.importCommitClient.commitReviewedImport = { receivedCommit in
                recordedCommit = receivedCommit
                return result
            }
        }

        await store.send(.task) {
            $0.status = .committing
        }

        await store.receive(.commitResponse(.success(result))) {
            $0.status = .completed(result)
        }

        await store.receive(.delegate(.completed(result)))
        #expect(recordedCommit == commit)
    }

    @Test("Falha de commit reporta notice e delega falha")
    func commitFailureReportsNoticeAndDelegatesFailure() async {
        let error = ImportCommitFeatureTestError.commitFailed
        var reportedTitle: String?
        let store = TestStore(initialState: ImportCommitFeature.State(commit: makeCommit())) {
            ImportCommitFeature()
        } withDependencies: {
            $0.importCommitClient.commitReviewedImport = { _ in throw error }
            $0.noticeClient.report = { _, title in
                reportedTitle = title
            }
        }

        await store.send(.task) {
            $0.status = .committing
        }

        await store.receive(.commitResponse(.failure(error))) {
            $0.status = .failed(message: error.localizedDescription)
        }

        await store.receive(.delegate(.failed(message: error.localizedDescription)))
        #expect(reportedTitle == "Falha ao finalizar importação")
    }

    @Test("Task não reexecuta commit já iniciado")
    func taskDoesNotRerunStartedCommit() async {
        var commitCount = 0
        let store = TestStore(
            initialState: ImportCommitFeature.State(
                commit: makeCommit(),
                status: .committing
            )
        ) {
            ImportCommitFeature()
        } withDependencies: {
            $0.importCommitClient.commitReviewedImport = { _ in
                commitCount += 1
                return ImportCommitResult(
                    batchIds: [],
                    importedRowCount: 0,
                    duplicateRows: []
                )
            }
        }

        await store.send(.task)
        #expect(commitCount == 0)
    }

    private func makeCommit() -> ReviewedImportCommit {
        ReviewedImportCommit(
            idempotencyKey: UUID(),
            reviewedRows: [],
            pendingBatches: [],
            categories: [],
            suggestions: []
        )
    }
}

private enum ImportCommitFeatureTestError: LocalizedError, Equatable {
    case commitFailed

    var errorDescription: String? {
        "commit failed"
    }
}
