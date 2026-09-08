import ComposableArchitecture
import Foundation

@Reducer
struct ImportWizardFeature {
    enum Phase: Equatable {
        case idle
        case loading(progress: String)
        case ofxReview
        case csvReview
        case categorizing
        case reviewingCategorization
        case confirming
        case done(batchIds: [UUID], rowCount: Int)
        case failed(message: String)
    }

    @ObservableState
    struct State: Equatable {
        let id = UUID()
        var initialFile: URL?
        var snapshot: ImportSnapshot = .empty
        var phase: Phase = .idle
        var sourceURL: URL?
        var pendingPlan: PendingImportPlan?
        var ofx: OFXImportFeature.State?
        var csv: CSVImportFeature.State?
        var categorization: ImportCategorizationFeature.State?
        var review: ImportReviewFeature.State?
        var commit: ImportCommitFeature.State?

        static let supportedExtensions: Set<String> = ImportFeatureConfiguration.supportedExtensions

        static func == (lhs: State, rhs: State) -> Bool {
            lhs.initialFile == rhs.initialFile
                && lhs.snapshot == rhs.snapshot
                && lhs.phase == rhs.phase
                && lhs.sourceURL == rhs.sourceURL
                && lhs.pendingPlan == rhs.pendingPlan
                && lhs.ofx == rhs.ofx
                && lhs.csv == rhs.csv
                && lhs.categorization == rhs.categorization
                && lhs.review == rhs.review
                && lhs.commit == rhs.commit
        }
    }

    enum Action: Equatable {
        case task
        case snapshotLoaded(TaskResult<ImportSnapshot>)
        case promptForFile
        case fileSelected(URL)
        case fileLoaded(TaskResult<ImportLoadedFile>)
        case confirmOFXImport
        case confirmCSVImport
        case reviewCompleted(ReviewedImportCommit)
        case backToPreview
        case cancel
        case ofx(OFXImportFeature.Action)
        case csv(CSVImportFeature.Action)
        case categorization(ImportCategorizationFeature.Action)
        case review(ImportReviewFeature.Action)
        case commit(ImportCommitFeature.Action)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case presentFileImporter
        case close
        case completed
    }

    @Dependency(\.importClient) private var importClient
    @Dependency(\.importPlanningClient) private var importPlanningClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                state.phase = .loading(progress: "Carregando dados…")
                return .run { [initialFile = state.initialFile] send in
                    await send(.snapshotLoaded(TaskResult { try await importClient.loadSnapshot() }))
                    if let initialFile {
                        await send(.fileSelected(initialFile))
                    } else {
                        await send(.promptForFile)
                    }
                }

            case let .snapshotLoaded(.success(snapshot)):
                state.snapshot = snapshot
                if case .loading = state.phase {
                    state.phase = .idle
                }
                return .none

            case let .snapshotLoaded(.failure(error)):
                state.phase = .failed(message: error.localizedDescription)
                return .run { _ in
                    await noticeClient.report(error, nil)
                }

            case .promptForFile:
                return .send(.delegate(.presentFileImporter))

            case let .fileSelected(url):
                state.phase = .loading(progress: "Lendo arquivo…")
                state.sourceURL = url
                return .run { [snapshot = state.snapshot] send in
                    await send(.fileLoaded(TaskResult { try await importClient.loadFile(url, snapshot) }))
                }
                .cancellable(id: "import.fileLoading", cancelInFlight: true)

            case let .fileLoaded(.success(file)):
                switch file {
                case let .ofx(sourceURL, resolutions):
                    state.sourceURL = sourceURL
                    state.csv = nil
                    state.ofx = OFXImportFeature.State(
                        resolutions: resolutions,
                        accounts: state.snapshot.accounts,
                        institutions: state.snapshot.institutions,
                        bankDetails: state.snapshot.bankDetails,
                        creditCards: state.snapshot.creditCards
                    )
                    state.phase = .ofxReview

                case let .csv(sourceURL, resolution):
                    state.sourceURL = sourceURL
                    state.ofx = nil
                    state.csv = CSVImportFeature.State(
                        resolution: resolution,
                        accounts: state.snapshot.accounts,
                        institutions: state.snapshot.institutions,
                        bankDetails: state.snapshot.bankDetails,
                        creditCards: state.snapshot.creditCards
                    )
                    state.phase = .csvReview
                }
                return .none

            case let .fileLoaded(.failure(error)):
                state.phase = .failed(message: error.localizedDescription)
                return .run { _ in
                    await noticeClient.report(error, "Erro ao abrir arquivo")
                }

            case .confirmOFXImport:
                guard let ofx = state.ofx else { return .none }
                let plan: PendingImportPlan
                do {
                    plan = try importPlanningClient.makePendingPlan(
                        .ofx(
                            sourceFilename: state.sourceURL?.lastPathComponent ?? "import.ofx",
                            resolutions: ofx.resolutions
                        ),
                        ImportPlanningContext(now: Date(), makeID: UUID.init)
                    )
                } catch {
                    return fail(&state, error: error)
                }

                state.pendingPlan = plan
                state.categorization = ImportCategorizationFeature.State()
                state.review = nil
                state.commit = nil
                state.phase = .categorizing
                return .send(.categorization(.start(plan.drafts)))

            case .confirmCSVImport:
                guard let csv = state.csv else { return .none }
                let plan: PendingImportPlan
                do {
                    plan = try importPlanningClient.makePendingPlan(
                        .interCreditCardCSV(
                            sourceFilename: csv.resolution.sourceFilename,
                            resolution: csv.resolution
                        ),
                        ImportPlanningContext(now: Date(), makeID: UUID.init)
                    )
                } catch {
                    return fail(&state, error: error)
                }

                state.pendingPlan = plan
                state.categorization = ImportCategorizationFeature.State()
                state.review = nil
                state.commit = nil
                state.phase = .categorizing
                return .send(.categorization(.start(plan.drafts)))

            case let .reviewCompleted(commit):
                state.review = nil
                state.commit = ImportCommitFeature.State(commit: commit)
                state.phase = .confirming
                return .none

            case .backToPreview:
                state.review = nil
                state.categorization = nil
                state.pendingPlan = nil
                state.commit = nil
                state.phase = state.csv != nil ? .csvReview : .ofxReview
                return .none

            case .cancel:
                state.phase = .idle
                state.sourceURL = nil
                state.pendingPlan = nil
                state.ofx = nil
                state.csv = nil
                state.categorization = nil
                state.review = nil
                state.commit = nil
                return .send(.delegate(.close))

            case .ofx:
                return .none

            case .csv:
                return .none

            case .categorization(.delegate(.ready)):
                guard let plan = state.pendingPlan,
                      let categorization = state.categorization
                else {
                    return fail(&state, error: ImportError.noValidRows)
                }
                state.review = ImportReviewFeature.State(
                    plan: plan,
                    suggestions: categorization.suggestions,
                    categories: categorization.categories,
                    accounts: categorization.accounts,
                    institutions: categorization.institutions
                )
                state.categorization = nil
                state.pendingPlan = nil
                state.commit = nil
                state.phase = .reviewingCategorization
                return .none

            case let .categorization(.delegate(.failed(message))):
                state.phase = .failed(message: message)
                return .none

            case .categorization:
                return .none

            case let .review(.delegate(.completed(commit))):
                return .send(.reviewCompleted(commit))

            case .review:
                return .none

            case let .commit(.delegate(.completed(result))):
                state.commit = nil
                state.phase = .done(batchIds: result.batchIds, rowCount: result.importedRowCount)
                return .send(.delegate(.completed))

            case let .commit(.delegate(.failed(message))):
                state.commit = nil
                state.phase = .failed(message: message)
                return .none

            case .commit:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.ofx, action: \.ofx) {
            OFXImportFeature()
        }
        .ifLet(\.csv, action: \.csv) {
            CSVImportFeature()
        }
        .ifLet(\.categorization, action: \.categorization) {
            ImportCategorizationFeature()
        }
        .ifLet(\.review, action: \.review) {
            ImportReviewFeature()
        }
        .ifLet(\.commit, action: \.commit) {
            ImportCommitFeature()
        }
    }

    private func fail(_ state: inout State, error: Error) -> Effect<Action> {
        state.phase = .failed(message: error.localizedDescription)
        return .run { _ in
            await noticeClient.report(error, nil)
        }
    }
}
