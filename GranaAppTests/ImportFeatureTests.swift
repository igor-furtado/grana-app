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
            $0.importHistoryClient.loadSnapshot = { snapshot }
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

    @Test("Histórico desfaz lote após confirmação")
    func historyUndoBatchAfterConfirmation() async {
        let batchId = UUID()
        let accountId = UUID()
        let importedAt = Date(timeIntervalSince1970: 1_787_970_600)
        let batch = ImportBatch(
            id: batchId,
            sourceFilename: "fatura-inter-2024-08.csv",
            accountId: accountId,
            rowCount: 70,
            importedAt: importedAt,
            createdAt: importedAt,
            updatedAt: importedAt
        )
        let store = TestStore(initialState: ImportHistoryFeature.State()) {
            ImportHistoryFeature()
        } withDependencies: {
            $0.importHistoryClient.undo = { undoBatchId in
                #expect(undoBatchId == batchId)
            }
            $0.importHistoryClient.loadSnapshot = { .empty }
        }

        await store.send(.undoButtonTapped(batch)) {
            $0.pendingDelete = batch
        }

        await store.send(.deleteConfirmationDismissed) {
            $0.pendingDelete = nil
        }

        await store.send(.undoButtonTapped(batch)) {
            $0.pendingDelete = batch
        }

        await store.send(.deleteConfirmed) {
            $0.pendingDelete = nil
        }

        await store.receive(.delegate(.financialDataChanged))

        await store.receive(.refresh) {
            $0.isLoading = true
        }

        await store.receive(.snapshotLoaded(.success(.empty))) {
            $0.snapshot = .empty
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    @Test("Desfazer lote no histórico sinaliza dados financeiros alterados")
    func historyUndoSignalsFinancialDataChangedFromImportFeature() async {
        let batchId = UUID()
        let accountId = UUID()
        let importedAt = Date(timeIntervalSince1970: 1_787_970_600)
        let batch = ImportBatch(
            id: batchId,
            sourceFilename: "fatura-inter-2024-08.csv",
            accountId: accountId,
            rowCount: 70,
            importedAt: importedAt,
            createdAt: importedAt,
            updatedAt: importedAt
        )
        let initialState = ImportFeature.State(
            history: ImportHistoryFeature.State(),
            wizard: nil
        )
        let store = TestStore(initialState: initialState) {
            ImportFeature()
        } withDependencies: {
            $0.importHistoryClient.undo = { undoBatchId in
                #expect(undoBatchId == batchId)
            }
            $0.importHistoryClient.loadSnapshot = { .empty }
        }

        await store.send(.history(.undoButtonTapped(batch))) {
            $0.history.pendingDelete = batch
        }

        await store.send(.history(.deleteConfirmed)) {
            $0.history.pendingDelete = nil
        }

        await store.receive(.history(.delegate(.financialDataChanged)))
        await store.receive(.delegate(.financialDataChanged))

        await store.receive(.history(.refresh)) {
            $0.history.isLoading = true
        }

        await store.receive(.history(.snapshotLoaded(.success(.empty)))) {
            $0.history.snapshot = .empty
            $0.history.isLoading = false
            $0.history.hasLoaded = true
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

    @Test("Conclusão do wizard sinaliza dados financeiros alterados")
    func wizardCompletionSignalsFinancialDataChanged() async {
        let initialState = ImportFeature.State(
            history: ImportHistoryFeature.State(),
            wizard: ImportWizardFeature.State(initialFile: URL(fileURLWithPath: "/tmp/fatura.csv"))
        )
        let store = TestStore(initialState: initialState) {
            ImportFeature()
        } withDependencies: {
            $0.importHistoryClient.loadSnapshot = {
                ImportSnapshot(
                    batches: [],
                    accounts: [],
                    institutions: [],
                    bankDetails: [],
                    creditCards: [],
                    categories: []
                )
            }
        }

        await store.send(.wizard(.delegate(.completed))) {
            $0.wizard = nil
        }

        await store.receive(.delegate(.financialDataChanged))

        await store.receive(.history(.refresh)) {
            $0.history.isLoading = true
        }

        await store.receive(.history(.snapshotLoaded(.success(.empty)))) {
            $0.history.snapshot = .empty
            $0.history.isLoading = false
            $0.history.hasLoaded = true
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

    @Test("CSV conta negativos selecionados na triagem")
    func csvResolutionCountsSelectedNegatives() {
        let balance = InterCreditCardCSVReader.SkippedRow(
            date: Date(),
            description: "CREDITO FATURA",
            amount: -10,
            kind: .balance
        )
        let payment = InterCreditCardCSVReader.SkippedRow(
            date: Date(),
            description: "PAGAMENTO FATURA",
            amount: -20,
            kind: .payment
        )
        let resolution = CSVStatementResolution(
            sourceFilename: "fatura.csv",
            accountId: UUID(),
            rows: [],
            negativeRows: [
                CSVNegativePreviewRow(raw: balance, selected: true),
                CSVNegativePreviewRow(raw: payment, selected: true),
            ]
        )

        #expect(resolution.selectedCount == 2)
    }

    @Test("CSV classifica negativo não pagamento como saldo")
    func csvReaderClassifiesNonPaymentNegativeAsBalance() throws {
        let csv = """
        Data,Lançamento,Categoria,Tipo,Valor
        29/05/2025,BONUS INTER,OUTROS,Crédito,"-R$ 18,02"
        30/05/2025,PAGAMENTO FATURA,PAGAMENTOS,Pagamento,"-R$ 120,00"
        """
        let data = csv.data(using: .utf8) ?? Data()

        let statement = try InterCreditCardCSVReader().read(data: data)

        #expect(statement.skippedNegatives.count == 2)
        #expect(statement.skippedNegatives.first?.kind == .balance)
        #expect(statement.skippedNegatives.last?.kind == .payment)
    }

    @Test("CSV extrai compra à vista e compra parcelada como metadados estruturados")
    func csvReaderExtractsStructuredPurchaseMetadata() throws {
        let csv = """
        Data,Lançamento,Categoria,Tipo,Valor
        31/08/2026,RESTAURANTE,ALIMENTACAO,Compra à vista,"R$ 50,00"
        31/01/2026,VIAGEM,VIAGEM,Parcela 8/10,"R$ 300,00"
        """
        let data = csv.data(using: .utf8) ?? Data()

        let statement = try InterCreditCardCSVReader().read(data: data)

        #expect(statement.rows.count == 2)
        #expect(statement.rows[0].purchaseType == .cash)
        #expect(statement.rows[0].installmentIndex == nil)
        #expect(statement.rows[0].installmentCount == nil)
        #expect(statement.rows[1].purchaseType == .installment)
        #expect(statement.rows[1].installmentIndex == 8)
        #expect(statement.rows[1].installmentCount == 10)
    }

    @Test("CSV gera external_id compatível com a chave persistida pelo backend")
    func csvReaderBuildsBackendCompatibleExternalId() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = try #require(calendar.date(from: DateComponents(
            calendar: calendar,
            year: 2023,
            month: 9,
            day: 5
        )))

        let externalId = InterCreditCardCSVReader.makeExternalId(
            date: date,
            description: "DESCOMPLICA Pos",
            amount: decimal("1453.50"),
            purchaseType: .cash,
            installmentIndex: nil,
            installmentCount: nil
        )

        #expect(externalId == "inter-cc:2023-09-05|descomplica pos|145350|cash|-|-")
    }

    @Test("CSV calcula competência de parcela a partir da data de origem")
    func csvReaderProjectsInstallmentCompetenceFromOriginDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let origin = try #require(calendar.date(from: DateComponents(
            calendar: calendar,
            year: 2026,
            month: 1,
            day: 31
        )))
        let row = InterCreditCardCSVReader.Row(
            date: origin,
            description: "VIAGEM",
            interCategory: "VIAGEM",
            tipo: "Parcela 3/10",
            purchaseType: .installment,
            installmentIndex: 3,
            installmentCount: 10,
            amount: Decimal(300)
        )

        let competence = InterCreditCardCSVReader.competenceDate(for: row, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day], from: competence)

        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 31)
    }

    @Test("Wizard OFX sem conta detectada pede criação antes da triagem")
    func wizardOFXWithoutDetectedAccountPromptsCreationBeforeTriage() async {
        let fileURL = URL(fileURLWithPath: "/tmp/extrato.ofx")
        let institution = makeCheckingInstitution(code: "001")
        let resolution = makeOFXResolution(accountId: nil)
        var initialState = ImportWizardFeature.State()
        initialState.snapshot = ImportSnapshot(
            batches: [],
            accounts: [],
            institutions: [institution],
            bankDetails: [],
            creditCards: [],
            categories: []
        )
        let store = TestStore(initialState: initialState) {
            ImportWizardFeature()
        }

        await store.send(.fileLoaded(.success(.ofx(
            sourceURL: fileURL,
            resolutions: [resolution]
        )))) {
            $0.sourceURL = fileURL
            $0.phase = .idle
            $0.pendingOFXSourceURL = fileURL
            $0.pendingOFXResolutions = [resolution]
            $0.destination = .accountCreationPrompt(OFXAccountCreationPromptFeature.State(
                statementIndex: 0,
                institutionId: institution.id,
                bankLabel: "Banco",
                accountLabel: "Ag 0001 Conta 123",
                accountKey: resolution.statement.account
            ))
        }
    }

    @Test("Wizard OFX seleciona conta criada e só então mostra triagem")
    func wizardOFXSelectsCreatedAccountBeforeTriage() async throws {
        let fileURL = URL(fileURLWithPath: "/tmp/extrato.ofx")
        let institution = makeCheckingInstitution(code: "001")
        let accountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000777"))
        let resolution = makeOFXResolution(accountId: nil)
        let item = makeCheckingAccountItem(
            id: accountId,
            institution: institution,
            accountNumber: "123"
        )
        let bankDetails = try #require(item.bankDetails)
        var initialState = ImportWizardFeature.State()
        initialState.snapshot = ImportSnapshot(
            batches: [],
            accounts: [],
            institutions: [institution],
            bankDetails: [],
            creditCards: [],
            categories: []
        )
        initialState.sourceURL = fileURL
        initialState.pendingOFXSourceURL = fileURL
        initialState.pendingOFXResolutions = [resolution]
        initialState.destination = .accountCreationPrompt(OFXAccountCreationPromptFeature.State(
            statementIndex: 0,
            institutionId: institution.id,
            bankLabel: "Banco",
            accountLabel: "Ag 0001 Conta 123",
            accountKey: resolution.statement.account
        ))
        let store = TestStore(initialState: initialState) {
            ImportWizardFeature()
        } withDependencies: {
            $0.accountsClient.loadList = {
                AccountsSnapshot(items: [item], institutions: [institution])
            }
            $0.importTriageClient.reloadOFXResolution = { resolution, selectedAccountId in
                var resolution = resolution
                resolution.accountId = selectedAccountId
                return resolution
            }
        }

        await store.send(.destination(.presented(.accountCreationPrompt(.delegate(.confirm))))) {
            $0.accountCreationStatementIndex = 0
            $0.destination = .accountForm(AccountFormFeature.State(
                institutions: [institution],
                checkingAccountPrefill: AccountFormFeature.CheckingAccountPrefill(
                    institutionId: institution.id,
                    branchId: "0001",
                    accountNumber: "123"
                )
            ))
        }
        await store.send(.destination(.presented(.accountForm(.delegate(.saved))))) {
            $0.destination = nil
            $0.accountCreationStatementIndex = nil
            $0.phase = .loading(progress: "Carregando conta criada…")
        }
        await store.receive(.accountSnapshotLoaded(
            statementIndex: 0,
            accountKey: resolution.statement.account,
            .success(AccountsSnapshot(items: [item], institutions: [institution]))
        )) {
            $0.snapshot.accounts = [item.account]
            $0.snapshot.institutions = [institution]
            $0.snapshot.bankDetails = [bankDetails]
        }
        var selectedResolution = resolution
        selectedResolution.accountId = accountId
        await store.receive(.fileLoaded(.success(.ofx(
            sourceURL: fileURL,
            resolutions: [selectedResolution]
        )))) {
            $0.pendingOFXSourceURL = nil
            $0.pendingOFXResolutions = nil
            $0.triage = ImportTriageFeature.State(
                sourceFilename: "extrato.ofx",
                content: .ofx(OFXTriageFeature.State(
                    resolutions: [selectedResolution],
                    accounts: [item.account],
                    institutions: [institution],
                    bankDetails: [bankDetails],
                    creditCards: []
                ))
            )
            $0.phase = .triage
        }
    }

    private func decimal(_ string: String) -> Decimal {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private func makeOFXResolution(accountId: UUID?) -> OFXStatementResolution {
        let date = Date(timeIntervalSince1970: 1_787_970_600)
        let transaction = OFXTransaction(
            trnType: "DEBIT",
            datePosted: date,
            amount: -12,
            fitid: "FIT-1",
            name: "Padaria",
            memo: nil,
            checkNumber: nil,
            refNumber: nil
        )
        let statement = OFXStatement(
            currency: "BRL",
            institutionHeader: OFXInstitutionHeader(organization: "Banco", fid: "001"),
            account: OFXAccountKey(bankId: "001", branchId: "0001", accountId: "123"),
            transactions: [transaction],
            balance: nil
        )
        return OFXStatementResolution(
            statement: statement,
            accountId: accountId,
            wasAutoDetected: accountId != nil,
            ofxBankLabel: "Banco",
            ofxAccountLabel: "Ag 0001 Conta 123",
            rows: [
                OFXPreviewRow(
                    raw: transaction,
                    derived: DerivedTransaction(
                        occurredAt: date,
                        amount: -12,
                        description: "Padaria",
                        notes: nil
                    ),
                    isDuplicate: false,
                    categoryId: UUID(),
                    subcategoryId: nil,
                    selected: true
                ),
            ]
        )
    }
}
