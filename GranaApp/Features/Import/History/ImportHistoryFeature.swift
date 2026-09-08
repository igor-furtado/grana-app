import ComposableArchitecture
import Foundation

@Reducer
struct ImportHistoryFeature {
    @ObservableState
    struct State: Equatable {
        var snapshot: ImportSnapshot = .empty
        var isLoading = false
        var hasLoaded = false
        var pendingDelete: ImportBatch?

        func account(for id: UUID) -> Account? {
            snapshot.accounts.first { $0.id == id }
        }

        var totalImportedRows: Int {
            snapshot.batches.reduce(0) { $0 + $1.rowCount }
        }

        var summarySubtitle: String {
            if snapshot.batches.isEmpty {
                return "Nenhuma importação ainda"
            }
            return "\(snapshot.batches.count) \(snapshot.batches.count == 1 ? "importação" : "importações") no histórico"
        }

        var latestImportShortText: String {
            guard let latest = snapshot.batches.max(by: { $0.importedAt < $1.importedAt }) else {
                return "Sem histórico"
            }
            return GranaDateFormat.fullDate(latest.importedAt)
        }
    }

    enum Action: Equatable {
        case task
        case refresh
        case snapshotLoaded(TaskResult<ImportSnapshot>)
        case importButtonTapped(URL?)
        case undoButtonTapped(ImportBatch)
        case deleteConfirmationDismissed
        case deleteConfirmed
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case startImport(URL?)
    }

    @Dependency(\.importHistoryClient) private var importHistoryClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task, .refresh:
                state.isLoading = true
                return .run { send in
                    await send(.snapshotLoaded(TaskResult { try await importHistoryClient.loadSnapshot() }))
                }

            case let .snapshotLoaded(.success(snapshot)):
                state.snapshot = snapshot
                state.isLoading = false
                state.hasLoaded = true
                return .none

            case let .snapshotLoaded(.failure(error)):
                state.isLoading = false
                state.hasLoaded = true
                return .run { _ in
                    await noticeClient.report(error, nil)
                }

            case let .importButtonTapped(file):
                return .send(.delegate(.startImport(file)))

            case let .undoButtonTapped(batch):
                state.pendingDelete = batch
                return .none

            case .deleteConfirmationDismissed:
                state.pendingDelete = nil
                return .none

            case .deleteConfirmed:
                guard let batch = state.pendingDelete else { return .none }
                state.pendingDelete = nil
                return .run { send in
                    do {
                        try await importHistoryClient.undo(batch.id)
                        await send(.refresh)
                    } catch {
                        await noticeClient.report(error, "Falha ao desfazer importação")
                    }
                }

            case .delegate:
                return .none
            }
        }
    }
}
