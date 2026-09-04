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

    @Dependency(\.importClient) private var importClient
    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task, .refresh:
                state.isLoading = true
                return .run { send in
                    await send(.snapshotLoaded(TaskResult { try await importClient.loadSnapshot() }))
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
                        try await importClient.undo(batch.id)
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
        var pendingDrafts: [TransactionDraft] = []
        var pendingBatches: [PendingImportBatch] = []
        var ofx: OFXImportFeature.State?
        var csv: CSVImportFeature.State?
        var categorization = CategorizationFeature.State()

        static let supportedExtensions: Set<String> = ImportFeatureConfiguration.supportedExtensions

        static func == (lhs: State, rhs: State) -> Bool {
            lhs.initialFile == rhs.initialFile
                && lhs.snapshot == rhs.snapshot
                && lhs.phase == rhs.phase
                && lhs.sourceURL == rhs.sourceURL
                && lhs.pendingDrafts == rhs.pendingDrafts
                && lhs.pendingBatches == rhs.pendingBatches
                && lhs.ofx == rhs.ofx
                && lhs.csv == rhs.csv
                && lhs.categorization == rhs.categorization
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
        case finalizeImport
        case backToPreview
        case cancel
        case ofx(OFXImportFeature.Action)
        case csv(CSVImportFeature.Action)
        case categorization(CategorizationFeature.Action)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case presentFileImporter
        case close
        case completed
    }

    @Dependency(\.importClient) private var importClient
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
                let resolved = ofx.resolutions.compactMap { resolution in
                    resolution.accountId.map { (resolution, $0) }
                }
                guard resolved.count == ofx.resolutions.count else {
                    return fail(&state, error: ImportError.accountNotSelected)
                }

                let now = Date()
                var pendingBatches: [PendingImportBatch] = []
                var pendingDrafts: [TransactionDraft] = []
                for (resolution, accountId) in resolved {
                    let selectedRows = resolution.rows.filter(\.selected)
                    if selectedRows.isEmpty {
                        continue
                    }
                    let batchId = UUID()
                    let batch = ImportBatch(
                        id: batchId,
                        sourceFilename: state.sourceURL?.lastPathComponent ?? "import.ofx",
                        accountId: accountId,
                        rowCount: selectedRows.count,
                        importedAt: now,
                        createdAt: now,
                        updatedAt: now
                    )
                    pendingBatches.append(PendingImportBatch(batch: batch, importFormat: .ofx))
                    pendingDrafts.append(contentsOf: selectedRows.map { row in
                        TransactionDraft(
                            id: UUID(),
                            accountId: accountId,
                            importBatchId: batchId,
                            signedAmount: row.derived.amount,
                            occurredAt: row.derived.occurredAt,
                            originOccurredAt: row.derived.occurredAt,
                            description: row.derived.description,
                            notes: row.derived.notes,
                            externalId: row.raw.fitid
                        )
                    })
                }

                guard !pendingDrafts.isEmpty else {
                    return fail(&state, error: ImportError.noValidRows)
                }

                state.pendingBatches = pendingBatches
                state.pendingDrafts = pendingDrafts
                state.phase = .categorizing
                return .send(.categorization(.start(pendingDrafts)))

            case .confirmCSVImport:
                guard let csv = state.csv else { return .none }
                guard let accountId = csv.resolution.accountId else {
                    return fail(&state, error: ImportError.accountNotSelected)
                }

                let purchasesToImport = csv.resolution.rows.filter(\.selected)
                let balancesToImport = csv.resolution.negativeRows.filter {
                    $0.raw.kind == .balance && $0.selected
                }
                guard !purchasesToImport.isEmpty || !balancesToImport.isEmpty else {
                    return fail(&state, error: ImportError.noValidRows)
                }

                let now = Date()
                let batchId = UUID()
                let batch = ImportBatch(
                    id: batchId,
                    sourceFilename: csv.resolution.sourceFilename,
                    accountId: accountId,
                    rowCount: purchasesToImport.count + balancesToImport.count,
                    importedAt: now,
                    createdAt: now,
                    updatedAt: now
                )

                var drafts = purchasesToImport.map { row in
                    TransactionDraft(
                        id: UUID(),
                        accountId: accountId,
                        importBatchId: batchId,
                        signedAmount: row.raw.amount,
                        occurredAt: row.derived.occurredAt,
                        originOccurredAt: row.raw.date,
                        purchaseType: row.raw.purchaseType,
                        installmentIndex: row.raw.installmentIndex,
                        installmentCount: row.raw.installmentCount,
                        description: row.derived.description,
                        notes: row.derived.notes,
                        externalId: row.externalId,
                        sourceCategoryHint: row.raw.interCategory
                    )
                }
                drafts.append(contentsOf: balancesToImport.map { row in
                    TransactionDraft(
                        id: UUID(),
                        accountId: accountId,
                        importBatchId: batchId,
                        signedAmount: abs(row.raw.amount),
                        occurredAt: row.raw.date,
                        originOccurredAt: row.raw.date,
                        description: row.raw.description,
                        notes: "Saldo importado do CSV Inter",
                        externalId: InterCreditCardCSVReader.makeExternalId(
                            date: row.raw.date,
                            description: row.raw.description,
                            amount: abs(row.raw.amount),
                            purchaseType: nil,
                            installmentIndex: nil,
                            installmentCount: nil
                        )
                    )
                })

                state.pendingDrafts = drafts
                state.pendingBatches = [PendingImportBatch(batch: batch, importFormat: .interCreditCardCSV)]
                state.phase = .categorizing
                return .send(.categorization(.start(drafts)))

            case .finalizeImport:
                guard state.phase == .reviewingCategorization else { return .none }
                guard !state.pendingDrafts.isEmpty else {
                    return fail(&state, error: ImportError.noValidRows)
                }

                state.phase = .confirming
                return .run { [pendingDrafts = state.pendingDrafts, pendingBatches = state.pendingBatches,
                                categories = state.snapshot.categories, suggestions = state.categorization.suggestions] send in
                    let reviewedRows = pendingDrafts.map { draft in
                        let resolved = suggestions.first(where: { $0.transactionId == draft.id })
                        return ReviewedImportRow(
                            draft: draft,
                            categoryId: resolved?.categoryId,
                            subcategoryId: resolved?.subcategoryId
                        )
                    }

                    do {
                        let input = try ImportCommitBuilder.buildInput(
                            idempotencyKey: UUID(),
                            reviewedRows: reviewedRows,
                            pendingBatches: pendingBatches,
                            categories: categories
                        )
                        let learnRequest = try ImportCommitBuilder.buildLearnRequest(
                            suggestions: suggestions,
                            categories: categories
                        )
                        _ = try await importClient.commit(input, learnRequest)
                        await send(.delegate(.completed))
                    } catch {
                        await send(.fileLoaded(.failure(error)))
                    }
                }
                .cancellable(id: "import.finalize", cancelInFlight: true)

            case .backToPreview:
                state.categorization = CategorizationFeature.State()
                state.pendingDrafts = []
                state.pendingBatches = []
                state.phase = state.csv != nil ? .csvReview : .ofxReview
                return .none

            case .cancel:
                state.phase = .idle
                state.sourceURL = nil
                state.pendingDrafts = []
                state.pendingBatches = []
                state.ofx = nil
                state.csv = nil
                state.categorization = CategorizationFeature.State()
                return .send(.delegate(.close))

            case .ofx:
                return .none

            case .csv:
                return .none

            case .categorization(.delegate(.ready)):
                state.phase = .reviewingCategorization
                return .none

            case let .categorization(.delegate(.failed(message))):
                state.phase = .failed(message: message)
                return .none

            case .categorization:
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
        Scope(state: \.categorization, action: \.categorization) {
            CategorizationFeature()
        }
    }

    private func fail(_ state: inout State, error: Error) -> Effect<Action> {
        state.phase = .failed(message: error.localizedDescription)
        return .run { _ in
            await noticeClient.report(error, nil)
        }
    }
}

@Reducer
struct ImportFeature {
    @ObservableState
    struct State: Equatable {
        var history = ImportHistoryFeature.State()
        var wizard: ImportWizardFeature.State?
    }

    enum Action: Equatable {
        case history(ImportHistoryFeature.Action)
        case wizard(ImportWizardFeature.Action)
        case globalFileDrop([URL])
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case financialDataChanged
    }

    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Scope(state: \.history, action: \.history) {
            ImportHistoryFeature()
        }
        Reduce { state, action in
            switch action {
            case let .globalFileDrop(urls):
                switch ImportDropPolicy.evaluate(
                    urls: urls,
                    supportedExtensions: ImportWizardFeature.State.supportedExtensions,
                    isImportInProgress: state.wizard != nil
                ) {
                case .ignore:
                    return .none

                case let .rejectUnsupported(extensionLabel):
                    return .run { _ in
                        await noticeClient.report(
                            ImportError.unsupportedFormat(extension: extensionLabel),
                            "Arquivo não suportado"
                        )
                    }

                case .rejectImportInProgress:
                    return .run { _ in
                        await noticeClient.info(
                            "Importação em andamento",
                            "Conclua ou cancele o arquivo atual antes de iniciar outra importação."
                        )
                    }

                case let .accept(url, droppedMultipleFiles):
                    state.wizard = ImportWizardFeature.State(initialFile: url)
                    guard droppedMultipleFiles else { return .none }
                    return .run { _ in
                        await noticeClient.info(
                            "Vários arquivos soltos",
                            "Importe um por vez. Abrindo \"\(url.lastPathComponent)\"."
                        )
                    }
                }

            case .history(.delegate(.startImport(let file))):
                state.wizard = ImportWizardFeature.State(initialFile: file)
                return .none

            case .wizard(.delegate(.close)):
                state.wizard = nil
                return .none

            case .wizard(.delegate(.completed)):
                state.wizard = nil
                return .merge(
                    .send(.delegate(.financialDataChanged)),
                    .send(.history(.refresh))
                )

            case .wizard(.delegate(.presentFileImporter)):
                return .none

            case .history, .wizard, .delegate:
                return .none
            }
        }
        .ifLet(\.wizard, action: \.wizard) {
            ImportWizardFeature()
        }
    }
}
