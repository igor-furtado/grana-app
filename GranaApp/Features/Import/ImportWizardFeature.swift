import ComposableArchitecture
import Foundation

@Reducer
struct ImportWizardFeature {
    @Reducer
    enum Destination {
        case accountCreationPrompt(OFXAccountCreationPromptFeature)
        case accountForm(AccountFormFeature)
    }

    enum Phase: Equatable {
        case idle
        case loading(progress: String)
        case triage
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
        var triage: ImportTriageFeature.State?
        var categorization: ImportCategorizationFeature.State?
        var review: ImportReviewFeature.State?
        var commit: ImportCommitFeature.State?
        var pendingOFXSourceURL: URL?
        var pendingOFXResolutions: [OFXStatementResolution]?
        var accountCreationStatementIndex: Int?

        @Presents var destination: Destination.State?

        static let supportedExtensions: Set<String> = ImportFeatureConfiguration.supportedExtensions

        static func == (lhs: State, rhs: State) -> Bool {
            lhs.initialFile == rhs.initialFile
                && lhs.snapshot == rhs.snapshot
                && lhs.phase == rhs.phase
                && lhs.sourceURL == rhs.sourceURL
                && lhs.pendingPlan == rhs.pendingPlan
                && lhs.triage == rhs.triage
                && lhs.categorization == rhs.categorization
                && lhs.review == rhs.review
                && lhs.commit == rhs.commit
                && lhs.pendingOFXSourceURL == rhs.pendingOFXSourceURL
                && lhs.pendingOFXResolutions == rhs.pendingOFXResolutions
                && lhs.accountCreationStatementIndex == rhs.accountCreationStatementIndex
                && lhs.destination == rhs.destination
        }
    }

    enum Action: Equatable {
        case task
        case snapshotLoaded(TaskResult<ImportSnapshot>)
        case promptForFile
        case fileSelected(URL)
        case fileLoaded(TaskResult<ImportLoadedFile>)
        case triage(ImportTriageFeature.Action)
        case reviewCompleted(ReviewedImportCommit)
        case backToPreview
        case cancel
        case categorization(ImportCategorizationFeature.Action)
        case review(ImportReviewFeature.Action)
        case commit(ImportCommitFeature.Action)
        case accountSnapshotLoaded(statementIndex: Int, accountKey: OFXAccountKey, TaskResult<AccountsSnapshot>)
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case presentFileImporter
        case close
        case completed
    }

    @Dependency(\.importFileLoadingClient) private var importFileLoadingClient
    @Dependency(\.importHistoryClient) private var importHistoryClient
    @Dependency(\.importPlanningClient) private var importPlanningClient
    @Dependency(\.accountsClient) private var accountsClient
    @Dependency(\.importTriageClient) private var importTriageClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                state.phase = .loading(progress: "Carregando dados…")
                return .run { [initialFile = state.initialFile] send in
                    await send(.snapshotLoaded(TaskResult { try await importHistoryClient.loadSnapshot() }))
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
                    await send(.fileLoaded(TaskResult { try await importFileLoadingClient.loadFile(url, snapshot) }))
                }
                .cancellable(id: "import.fileLoading", cancelInFlight: true)

            case let .fileLoaded(.success(file)):
                switch file {
                case let .ofx(sourceURL, resolutions):
                    state.sourceURL = sourceURL
                    state.pendingOFXSourceURL = nil
                    state.pendingOFXResolutions = nil
                    return prepareOFXFlow(&state, sourceURL: sourceURL, resolutions: resolutions)

                case let .csv(sourceURL, resolution):
                    state.sourceURL = sourceURL
                    state.triage = ImportTriageFeature.State(
                        sourceFilename: sourceURL.lastPathComponent,
                        content: .csv(CSVTriageFeature.State(
                            resolution: resolution,
                            accounts: state.snapshot.accounts,
                            institutions: state.snapshot.institutions,
                            bankDetails: state.snapshot.bankDetails,
                            creditCards: state.snapshot.creditCards
                        ))
                    )
                    state.phase = .triage
                }
                return .none

            case let .fileLoaded(.failure(error)):
                state.phase = .failed(message: error.localizedDescription)
                return .run { _ in
                    await noticeClient.report(error, "Erro ao abrir arquivo")
                }

            case let .triage(.delegate(.confirmed(triage))):
                let plan: PendingImportPlan
                do {
                    plan = try importPlanningClient.makePendingPlan(
                        triage,
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

            case .triage:
                return .none

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
                state.phase = .triage
                return .none

            case .cancel:
                state.phase = .idle
                state.sourceURL = nil
                state.pendingPlan = nil
                state.triage = nil
                state.categorization = nil
                state.review = nil
                state.commit = nil
                state.pendingOFXSourceURL = nil
                state.pendingOFXResolutions = nil
                state.accountCreationStatementIndex = nil
                state.destination = nil
                return .send(.delegate(.close))

            case .destination(.presented(.accountCreationPrompt(.delegate(.cancel)))):
                return .send(.cancel)

            case .destination(.presented(.accountCreationPrompt(.delegate(.confirm)))):
                guard let prompt = state.accountCreationPrompt,
                      let resolutions = state.pendingOFXResolutions,
                      resolutions.indices.contains(prompt.statementIndex)
                else {
                    return .send(.cancel)
                }
                state.accountCreationStatementIndex = prompt.statementIndex
                state.destination = .accountForm(AccountFormFeature.State(
                    institutions: state.snapshot.institutions,
                    checkingAccountPrefill: AccountFormFeature.CheckingAccountPrefill(
                        institutionId: prompt.institutionId,
                        branchId: prompt.accountKey.branchId ?? "",
                        accountNumber: prompt.accountKey.accountId
                    )
                ))
                return .none

            case .destination(.presented(.accountForm(.delegate(.cancel)))):
                return .send(.cancel)

            case .destination(.presented(.accountForm(.delegate(.saved)))):
                guard let statementIndex = state.accountCreationStatementIndex,
                      let resolutions = state.pendingOFXResolutions,
                      resolutions.indices.contains(statementIndex)
                else {
                    return .send(.cancel)
                }
                let accountKey = resolutions[statementIndex].statement.account
                state.destination = nil
                state.accountCreationStatementIndex = nil
                state.phase = .loading(progress: "Carregando conta criada…")
                return .run { send in
                    await send(.accountSnapshotLoaded(
                        statementIndex: statementIndex,
                        accountKey: accountKey,
                        TaskResult { try await accountsClient.loadList() }
                    ))
                }

            case let .accountSnapshotLoaded(statementIndex, accountKey, .success(accountsSnapshot)):
                state.snapshot.accounts = mergeCheckingAccounts(
                    existingAccounts: state.snapshot.accounts,
                    checkingAccounts: accountsSnapshot.items.map(\.account)
                )
                state.snapshot.institutions = accountsSnapshot.institutions
                state.snapshot.bankDetails = accountsSnapshot.items.compactMap(\.bankDetails)

                guard let sourceURL = state.pendingOFXSourceURL,
                      let resolutions = state.pendingOFXResolutions,
                      resolutions.indices.contains(statementIndex),
                      let accountId = matchedAccountId(
                          for: accountKey,
                          accounts: state.snapshot.accounts,
                          institutions: state.snapshot.institutions,
                          bankDetails: state.snapshot.bankDetails
                      )
                else {
                    return fail(&state, error: ImportError.accountNotSelected)
                }

                let resolution = resolutions[statementIndex]
                return .run { send in
                    let updated = await importTriageClient.reloadOFXResolution(resolution, accountId)
                    await send(.fileLoaded(.success(.ofx(
                        sourceURL: sourceURL,
                        resolutions: resolutions.replacingElement(at: statementIndex, with: updated)
                    ))))
                }

            case let .accountSnapshotLoaded(_, _, .failure(error)):
                return fail(&state, error: error)

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

            case .destination:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.triage, action: \.triage) {
            ImportTriageFeature()
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
        .ifLet(\.$destination, action: \.destination)
    }

    private func fail(_ state: inout State, error: Error) -> Effect<Action> {
        state.phase = .failed(message: error.localizedDescription)
        return .run { _ in
            await noticeClient.report(error, nil)
        }
    }

    private func prepareOFXFlow(
        _ state: inout State,
        sourceURL: URL,
        resolutions: [OFXStatementResolution]
    ) -> Effect<Action> {
        if let unresolvedIndex = resolutions.firstIndex(where: { $0.accountId == nil }) {
            state.phase = .idle
            state.pendingOFXSourceURL = sourceURL
            state.pendingOFXResolutions = resolutions
            state.triage = nil
            let resolution = resolutions[unresolvedIndex]
            guard let institution = suggestedInstitution(
                for: resolution.statement.account,
                institutions: state.snapshot.institutions
            ) else {
                return fail(&state, error: ImportError.accountNotSelected)
            }
            state.destination = .accountCreationPrompt(OFXAccountCreationPromptFeature.State(
                statementIndex: unresolvedIndex,
                institutionId: institution.id,
                bankLabel: resolution.ofxBankLabel,
                accountLabel: resolution.ofxAccountLabel,
                accountKey: resolution.statement.account
            ))
            return .none
        }

        state.pendingOFXSourceURL = nil
        state.pendingOFXResolutions = nil
        state.accountCreationStatementIndex = nil
        state.destination = nil
        state.triage = ImportTriageFeature.State(
            sourceFilename: sourceURL.lastPathComponent,
            content: .ofx(OFXTriageFeature.State(
                resolutions: resolutions,
                accounts: state.snapshot.accounts,
                institutions: state.snapshot.institutions,
                bankDetails: state.snapshot.bankDetails,
                creditCards: state.snapshot.creditCards
            ))
        )
        state.phase = .triage
        return .none
    }
}

extension ImportWizardFeature.Destination.State: Equatable {}
extension ImportWizardFeature.Destination.Action: Equatable {}

@Reducer
struct OFXAccountCreationPromptFeature {
    @ObservableState
    struct State: Equatable {
        let statementIndex: Int
        let institutionId: UUID
        let bankLabel: String
        let accountLabel: String
        let accountKey: OFXAccountKey
    }

    enum Action: Equatable {
        case cancelButtonTapped
        case confirmButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case cancel
        case confirm
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .cancelButtonTapped:
                return .send(.delegate(.cancel))
            case .confirmButtonTapped:
                return .send(.delegate(.confirm))
            case .delegate:
                return .none
            }
        }
    }
}

private extension ImportWizardFeature.State {
    var accountCreationPrompt: OFXAccountCreationPromptFeature.State? {
        guard case let .accountCreationPrompt(prompt) = destination else { return nil }
        return prompt
    }
}

private extension Array {
    func replacingElement(at index: Index, with element: Element) -> [Element] {
        var copy = self
        copy[index] = element
        return copy
    }
}

private func suggestedInstitution(
    for accountKey: OFXAccountKey,
    institutions: [Institution]
) -> Institution? {
    guard let institution = institutions.institution(code: accountKey.bankId, supporting: .ofx),
          institution.capabilities.supports(.checking)
    else { return nil }

    return institution
}

private func mergeCheckingAccounts(
    existingAccounts: [Account],
    checkingAccounts: [Account]
) -> [Account] {
    let checkingAccountIds = Set(checkingAccounts.map(\.id))
    return existingAccounts.filter {
        $0.type != .checking && !checkingAccountIds.contains($0.id)
    } + checkingAccounts
}

private func matchedAccountId(
    for accountKey: OFXAccountKey,
    accounts: [Account],
    institutions: [Institution],
    bankDetails: [BankAccountDetails]
) -> UUID? {
    guard let institution = institutions.institution(code: accountKey.bankId, supporting: .ofx) else {
        return nil
    }

    return accounts.first { account in
        guard account.institutionId == institution.id,
              let details = bankDetails.first(where: { $0.accountId == account.id })
        else { return false }

        return details.accountNumber == accountKey.accountId
            && details.branchId == accountKey.branchId
    }?.id
}
