import ComposableArchitecture
import Foundation

@Reducer
struct ImportCommitFeature {
    enum Status: Equatable {
        case idle
        case committing
        case completed(ImportCommitResult)
        case failed(message: String)
    }

    @ObservableState
    struct State: Equatable {
        var commit: ReviewedImportCommit
        var status: Status = .idle
    }

    enum Action: Equatable {
        case task
        case commitResponse(TaskResult<ImportCommitResult>)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case completed(ImportCommitResult)
        case failed(message: String)
    }

    @Dependency(\.importCommitClient) private var importCommitClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard state.status == .idle else { return .none }
                state.status = .committing
                return .run { [commit = state.commit] send in
                    await send(.commitResponse(TaskResult {
                        try await importCommitClient.commitReviewedImport(commit)
                    }))
                }
                .cancellable(id: "import.commit", cancelInFlight: true)

            case let .commitResponse(.success(result)):
                state.status = .completed(result)
                return .send(.delegate(.completed(result)))

            case let .commitResponse(.failure(error)):
                guard !AppErrorPresentation.isExpectedCancellation(error) else {
                    state.status = .idle
                    return .none
                }
                let message = error.localizedDescription
                state.status = .failed(message: message)
                return .run { send in
                    await noticeClient.report(error, "Falha ao finalizar importação")
                    await send(.delegate(.failed(message: message)))
                }

            case .delegate:
                return .none
            }
        }
    }
}
