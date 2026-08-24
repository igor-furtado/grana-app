import Foundation
import Observation
import OSLog

/// Estado observável do wizard de importação OFX.
///
/// Fluxo: `idle → loading → ofxReview → categorizing → reviewingCategorization
/// → confirming → done` (ou `failed` em qualquer transição).
///
/// Cada `STMTRS` do OFX vira um batch independente; múltiplas contas no
/// mesmo arquivo geram múltiplas operações de auto-create — tudo em uma
/// única `writeTransaction` pra atomicidade.
@MainActor
@Observable
final class ImportStore {
    static let didMutateImportsNotification = Notification.Name("ImportStore.didMutateImports")

    enum Phase: Equatable {
        case idle
        /// Após o file picker, antes do `ofxReview`. Parsing + dedup
        /// podem demorar em extratos grandes (centenas de transações) —
        /// sem esse estado a UI parece travada.
        case loading(progress: String)
        case ofxReview
        /// Fase 4.5: preview de fatura de cartão importada via CSV (Inter).
        /// Diferente do OFX, não tem auto-detect — usuário escolhe a conta-cartão
        /// no próprio preview.
        case csvReview
        /// Montando sugestões locais para revisão pré-commit. Drafts já
        /// montados, transações ainda NÃO foram inseridas no banco.
        case categorizing
        /// Tela de revisão das classificações antes do commit. Cancelar
        /// aqui descarta tudo; "Importar" finaliza.
        case reviewingCategorization
        case confirming
        case done(batchIds: [UUID], rowCount: Int)
        case failed(message: String)
    }

    /// Extensões aceitas pelo `loadFile`. Single source of truth — o drop
    /// target em `ImportHistoryView` e qualquer outro callsite que precise
    /// validar extensão consomem daqui pra não ficar fora de sincronia
    /// quando um formato novo entrar.
    static let supportedExtensions: Set<String> = ["ofx", "csv"]

    private let container: AppContainer

    private(set) var phase: Phase = .idle

    /// Store de classificação compartilhado entre os steps do wizard.
    /// Disparado **antes** do commit ao banco; a tela de revisão é parte do
    /// fluxo. Cancelar o import descarta tudo.
    let categorization: CategorizationStore

    // Estado "em voo" entre o preview e o commit final. Construído
    // pelo `confirmOFXImport`; consumido pelo `finalizeImport`.
    //
    // Não há mais criação de Institution/Account no commit — a partir da
    // Fase 4.5 a importação **exige** uma conta existente escolhida pelo
    // usuário. Drafts ficam só pra transactions + batches. Privados porque
    // nenhum caller fora do store precisa ler — fluxo é confirm → categorize
    // → finalize, todo dentro deste arquivo.
    private var pendingDrafts: [TransactionDraft] = []
    private var pendingBatches: [PendingImportBatch] = []
    private let makeIdempotencyKey: @Sendable () -> UUID

    /// Contexto do arquivo aberto. Fica fora do `Phase` pra sobreviver às
    /// transições.
    private(set) var sourceURL: URL?

    /// Fluxo OFX.
    private(set) var ofxDocument: OFXDocument?
    var ofxResolutions: [OFXStatementResolution] = []

    /// Fluxo CSV de fatura de cartão (Inter). Diferente do OFX, é uma única
    /// resolução (uma fatura = uma conta-cartão).
    var csvResolution: CSVStatementResolution?

    private(set) var batches: [ImportBatch] = []
    private(set) var accounts: [Account] = []
    private(set) var institutions: [Institution] = []
    /// Details das tabelas-irmãs de Account — necessários pra montar o display
    /// name com sufixo (número da conta / ••••last4) nos pickers e cabeçalhos
    /// do preview. Fase 4.6+.
    private(set) var bankDetails: [BankAccountDetails] = []
    private(set) var creditCards: [CreditCardDetails] = []
    /// Carregadas no `loadInitialData` pra alimentar os pickers de
    /// categoria/subcategoria do preview OFX sem chamar o repo a cada View.
    private(set) var categories: [Category] = []
    private(set) var csvRefundPurchases: [Transaction] = []

    /// Task que espera a categorização terminar pra avançar a fase. Guardada
    /// pra que `cancel()` consiga interromper o polling — sem isso, cancelar
    /// no meio do `.categorizing` deixa um loop rodando indefinidamente.
    private var categorizationWaitTask: Task<Void, Never>?

    init(
        container: AppContainer,
        makeIdempotencyKey: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.container = container
        self.categorization = CategorizationStore(container: container)
        self.makeIdempotencyKey = makeIdempotencyKey
    }

    // MARK: - Classificação pré-commit

    /// Dispara a classificação local pré-commit para os drafts em voo.
    /// Move o wizard pra `.categorizing` e observa a conclusão pra avançar
    /// pra `.reviewingCategorization`.
    private func startCategorization() {
        phase = .categorizing
        categorizationWaitTask?.cancel()
        categorizationWaitTask = Task { [weak self] in
            guard let self else { return }
            await self.categorization.loadCategories()
            self.categorization.classifyDrafts(self.pendingDrafts)
            await self.awaitCategorizationCompletion()
        }
    }

    private func awaitCategorizationCompletion() async {
        // Aguarda a task interna do CategorizationStore terminar e então
        // inspeciona o status pra decidir a fase. Sem polling — o
        // CategorizationStore expõe `waitForCompletion()` que faz
        // `await currentTask?.value`.
        //
        // `.idle` significa "cancelado" (inner Task entrou no catch de
        // CancellationError) — sai sem mudar fase, quem cancelou cuida.
        await categorization.waitForCompletion()
        guard !Task.isCancelled else { return }

        switch categorization.status {
        case .ready:
            phase = .reviewingCategorization
        case let .failed(message):
            phase = .failed(message: message)
        case .idle, .classifying:
            // Cancelado (idle) ou estado inesperado — não mexe na fase.
            return
        }
    }

    // MARK: - Bootstrap

    /// Snapshot one-shot pros dados que o **wizard** (`ImportView`) precisa
    /// resolvidos *antes* de montar os pickers e processar o arquivo — ex:
    /// `loadCSV` lê `accounts` sincronamente pra pré-selecionar a conta-cartão.
    /// Por isso aqui é `getAll` sequencial (garante populado ao retornar), não
    /// stream. A tela de histórico usa `start()` em vez disso.
    func loadInitialData() async {
        async let institutionsTask = container.institutionCatalog.load()
        async let categoriesTask = container.categoryCatalog.load()

        do {
            institutions = try await institutionsTask
        } catch {
            NoticeCenter.shared.report(error)
        }

        do {
            categories = try await categoriesTask
        } catch {
            NoticeCenter.shared.report(error)
        }

        do {
            let accountSnapshot = try await container.remoteAccounts.load()
            accounts = accountSnapshot.accounts
            bankDetails = accountSnapshot.bankDetails
            creditCards = accountSnapshot.creditCards
        } catch {
            NoticeCenter.shared.report(error)
        }

        do {
            batches = try await container.remoteImports.loadBatches()
        } catch {
            NoticeCenter.shared.report(error)
        }
    }

    /// Snapshot explícito que alimenta a tela de Histórico de Importações.
    func start() async {
        await refresh()
    }

    func refresh() async {
        await loadInitialData()
    }

    func refreshCatalogs() async {
        do {
            async let institutionsTask = container.institutionCatalog.load()
            async let categoriesTask = container.categoryCatalog.load()
            institutions = try await institutionsTask
            categories = try await categoriesTask
        } catch {
            NoticeCenter.shared.report(error)
        }
    }

    // MARK: - Category helpers (pra UI)

    var rootCategories: [Category] {
        categories.filter { $0.parentId == nil }
    }

    func subcategories(of parentId: UUID) -> [Category] {
        categories.filter { $0.parentId == parentId }
    }

    func category(for id: UUID) -> Category? {
        categories.first { $0.id == id }
    }

    func refreshBatches() async {
        do {
            batches = try await container.remoteImports.loadBatches()
        } catch {
            NoticeCenter.shared.report(error)
        }
    }

    func account(for id: UUID) -> Account? {
        accounts.first { $0.id == id }
    }

    // MARK: - File loading

    func loadFile(url: URL) async {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        do {
            sourceURL = url
            let ext = url.pathExtension.lowercased()
            if ext == "csv" {
                try await loadCSV(url: url)
            } else {
                try await loadOFX(url: url)
            }
        } catch {
            fail(with: error)
        }
    }

    /// Reporta uma falha originada **fora** do `loadFile` — tipicamente um
    /// erro do `fileImporter` da SwiftUI (permissão negada, sandbox, etc.).
    /// Sem isso a UI ficava silenciosa quando o picker do sistema falhava.
    func reportFileImportFailure(_ error: Error) {
        fail(with: error, title: "Erro ao abrir arquivo")
    }

    /// Helper único pra transição `→ .failed`: garante que o erro vai sempre
    /// pro `NoticeCenter` (toast pro usuário) e o `phase` muda. Como o
    /// `ImportView` fecha a sheet automaticamente em `.failed`, deixar de
    /// reportar aqui vira tela escondida sem feedback nenhum. Centralizar
    /// evita esquecer um caminho.
    private func fail(with error: Error, title: String? = nil) {
        if let title {
            NoticeCenter.shared.report(error, title: title)
        } else {
            NoticeCenter.shared.report(error)
        }
        phase = .failed(message: error.localizedDescription)
    }

    /// Lê OFX → cria `ofxResolutions` (uma por `STMTRS`) com auto-detect de
    /// instituição/conta + parsing de cada transação + detecção de duplicata
    /// via FITID. Move pra `.ofxReview`.
    private func loadOFX(url: URL) async throws {
        phase = .loading(progress: "Lendo arquivo…")
        let reader = OFXReader()
        let document = try reader.read(from: url)
        ofxDocument = document

        phase = .loading(progress: "Resolvendo categorias…")
        // Resolver categorias raiz uma vez — heurística reusa os IDs.
        let heuristic = try await buildHeuristic()

        var resolutions: [OFXStatementResolution] = []
        for (idx, statement) in document.statements.enumerated() {
            phase = .loading(progress: document.statements.count > 1
                ? "Processando conta \(idx + 1) de \(document.statements.count)…"
                : "Processando \(statement.transactions.count) transações…")
            let resolution = try await resolveStatement(statement, heuristic: heuristic)
            resolutions.append(resolution)
        }
        ofxResolutions = resolutions

        if resolutions.allSatisfy({ $0.rows.isEmpty }) {
            fail(with: ImportError.noValidRows)
            return
        }
        phase = .ofxReview
    }

    /// Materializa uma `OFXStatementResolution` a partir de um `OFXStatement`
    /// parseado. Tenta auto-detectar uma conta existente que bate com a
    /// identidade bancária (instituição+agência+número). Se não achar,
    /// `accountId` fica nil e o usuário precisa escolher uma conta existente
    /// no preview — **não criamos contas novas a partir do import** (MVP).
    private func resolveStatement(
        _ statement: OFXStatement,
        heuristic: OFXCategoryHeuristic
    ) async throws -> OFXStatementResolution {
        let matchedAccountId = try await autoDetectAccountId(for: statement)

        // **Batched dedup**: pra contas existentes, busca TODOS os FITIDs já
        // gravados de uma vez e converte pra Set. O check por linha vira O(1)
        // em memória em vez de uma query por linha — em extratos com 500+
        // transações isso é a diferença entre <1s e 30+s.
        let existingExternalIds: Set<String>
        if let matchedAccountId {
            existingExternalIds = (try? await container.remoteTransactions.externalIds(forAccount: matchedAccountId)) ?? []
        } else {
            existingExternalIds = []
        }

        let rows = buildOFXRows(
            for: statement,
            existingExternalIds: existingExternalIds,
            heuristic: heuristic
        )

        return OFXStatementResolution(
            statement: statement,
            accountId: matchedAccountId,
            wasAutoDetected: matchedAccountId != nil,
            ofxBankLabel: ofxBankLabel(for: statement),
            ofxAccountLabel: ofxAccountLabel(for: statement),
            rows: rows
        )
    }

    /// Constrói as `OFXPreviewRow` aplicando dedup contra um set já carregado.
    /// Extraído pra ser reusado no `setOFXAccount` quando o usuário troca a
    /// conta no picker — re-dedup roda sem refazer o parse inteiro.
    private func buildOFXRows(
        for statement: OFXStatement,
        existingExternalIds: Set<String>,
        heuristic: OFXCategoryHeuristic
    ) -> [OFXPreviewRow] {
        var rows: [OFXPreviewRow] = []
        rows.reserveCapacity(statement.transactions.count)
        for trn in statement.transactions {
            let isDuplicate = existingExternalIds.contains(trn.fitid)
            let derived = DerivedTransaction(
                occurredAt: trn.datePosted,
                amount: trn.amount,
                description: trn.displayDescription,
                notes: trn.memo
            )
            // Defaults sensatos: válidas selecionadas, duplicadas desligadas.
            // Usuário re-marca duplicadas explicitamente caso queira re-importar.
            rows.append(OFXPreviewRow(
                raw: trn,
                derived: derived,
                isDuplicate: isDuplicate,
                categoryId: heuristic.categoryId(for: trn),
                subcategoryId: nil,
                selected: !isDuplicate
            ))
        }
        return rows
    }

    /// Procura uma conta existente que bata com o `<BANKACCTFROM>` do OFX via
    /// instituição (pelo `bankId` / FID) + agência + número. Retorna `nil` se
    /// qualquer parte não bater — usuário precisa escolher manualmente.
    private func autoDetectAccountId(for statement: OFXStatement) async throws -> UUID? {
        let code = statement.account.bankId
        guard let institution = institutions.institution(code: code, supporting: .ofx) else {
            return nil
        }
        return accounts.first { account in
            guard account.institutionId == institution.id else { return false }
            guard let details = bankDetails.first(where: { $0.accountId == account.id }) else { return false }
            return details.accountNumber == statement.account.accountId
                && details.branchId == statement.account.branchId
        }?.id
    }

    /// Label do banco vindo do OFX pra exibição no header da Section. Usa o
    /// `<FI><ORG>` quando disponível; cai pro `displayName` do `InstitutionKind`
    /// derivado do FID quando o cabeçalho `<FI>` está vazio (acontece em OFX
    /// legados).
    private func ofxBankLabel(for statement: OFXStatement) -> String {
        if let org = statement.institutionHeader.organization, !org.isEmpty {
            return org
        }
        if let institution = institutions.institution(code: statement.account.bankId) {
            return institution.name
        }
        return statement.account.bankId
    }

    /// Label da conta vindo do OFX pra exibição. Formata `código · agência ·
    /// conta` compactamente — é o que o usuário precisa pra reconhecer "essa
    /// conta do extrato é qual das minhas".
    private func ofxAccountLabel(for statement: OFXStatement) -> String {
        var parts: [String] = [statement.account.accountId]
        if let branch = statement.account.branchId, !branch.isEmpty {
            parts.append("Ag \(branch)")
        }
        parts.append("cód. \(statement.account.bankId)")
        return parts.joined(separator: " · ")
    }

    /// Trocar a conta selecionada no preview OFX exige refazer o dedup contra
    /// o novo conjunto de external_ids — sem isso, o badge "Já importada"
    /// ficaria desatualizado.
    func setOFXAccount(statementIndex idx: Int, to accountId: UUID?) async {
        guard ofxResolutions.indices.contains(idx) else { return }
        var resolution = ofxResolutions[idx]
        resolution.accountId = accountId
        resolution.wasAutoDetected = false

        let existingExternalIds: Set<String>
        if let accountId {
            existingExternalIds = (try? await container.remoteTransactions.externalIds(forAccount: accountId)) ?? []
        } else {
            existingExternalIds = []
        }

        // Re-aplica dedup mantendo a categoria já resolvida pela heurística.
        // `selected` só é recalculado quando o flag `isDuplicate` muda — assim
        // qualquer decisão manual do usuário (desmarcar uma row não-duplicada
        // que ele não quer importar) é preservada ao trocar a conta.
        for rowIdx in resolution.rows.indices {
            let fitid = resolution.rows[rowIdx].raw.fitid
            let wasDup = resolution.rows[rowIdx].isDuplicate
            let isDup = existingExternalIds.contains(fitid)
            resolution.rows[rowIdx].isDuplicate = isDup
            if wasDup != isDup {
                resolution.rows[rowIdx].selected = !isDup
            }
        }
        ofxResolutions[idx] = resolution
    }

    /// Resolve as categorias raiz "Não Classificado", "Transferências" e
    /// "Renda e Pagamentos" pra alimentar a heurística. As duas últimas são
    /// opcionais (a heurística cai pra unclassified se faltarem).
    private func buildHeuristic() async throws -> OFXCategoryHeuristic {
        guard let unclassified = categories.rootCategory(slug: "nao-classificado") else {
            throw ImportError.unclassifiedCategoryMissing
        }
        let transfers = categories.rootCategory(slug: "transferencias")
        let income = categories.rootCategory(slug: "renda-e-pagamentos")
        return OFXCategoryHeuristic(roots: .init(
            unclassified: unclassified.id,
            transfers: transfers?.id,
            income: income?.id
        ))
    }

    // MARK: - CSV de fatura de cartão (Fase 4.5)

    /// Lê CSV de fatura de cartão (Inter) → monta uma única `CSVStatementResolution`
    /// com as linhas válidas. **Exige conta-cartão existente** — se o usuário
    /// não tem nenhuma cadastrada, falha com mensagem orientando a criar uma
    /// antes (MVP simplificado: import nunca cria contas). Pré-seleciona
    /// quando há uma única conta-cartão pra reduzir cliques.
    private func loadCSV(url: URL) async throws {
        phase = .loading(progress: "Lendo fatura…")
        let reader = InterCreditCardCSVReader()
        let statement = try reader.read(from: url)

        // Arquivadas ficam fora — o usuário tirou do dia-a-dia, importar pra
        // elas seria inesperado. Desarquivar é o passo explícito.
        let creditCardAccounts = accounts.filter { $0.type == .creditCard && !$0.archived }
        if creditCardAccounts.isEmpty {
            throw ImportError.noCreditCardAccount
        }
        let initialAccountId: UUID? = creditCardAccounts.count == 1
            ? creditCardAccounts.first?.id
            : nil

        let rows: [CSVPreviewRow] = statement.rows.map { raw in
            let externalId = InterCreditCardCSVReader.makeExternalId(
                date: raw.date,
                description: raw.description,
                amount: raw.amount,
                tipo: raw.tipo
            )
            return CSVPreviewRow(
                raw: raw,
                derived: DerivedTransaction(
                    occurredAt: raw.date,
                    amount: raw.amount,
                    description: raw.description,
                    notes: "\(raw.tipo) · \(raw.interCategory)"
                ),
                externalId: externalId,
                isDuplicate: false,
                selected: true
            )
        }

        var resolution = CSVStatementResolution(
            sourceFilename: url.lastPathComponent,
            accountId: initialAccountId,
            rows: rows,
            negativeRows: statement.skippedNegatives.map {
                CSVNegativePreviewRow(raw: $0, purchaseId: nil)
            }
        )

        if let accId = initialAccountId {
            resolution = await applyCSVDedup(resolution, accountId: accId)
            await loadCSVRefundPurchases(accountId: accId)
        }

        csvResolution = resolution
        phase = .csvReview
    }

    /// Re-aplica dedup quando o usuário muda a conta-cartão no picker.
    /// Sem isso, o preview mostra "Já importada" baseado na conta anterior.
    func setCSVAccount(_ accountId: UUID?) async {
        guard var resolution = csvResolution else { return }
        resolution.accountId = accountId

        if let accId = accountId {
            resolution = await applyCSVDedup(resolution, accountId: accId)
            await loadCSVRefundPurchases(accountId: accId)
        } else {
            // Sem conta selecionada → limpa flags de duplicata e deixa tudo
            // selecionado por default.
            for idx in resolution.rows.indices {
                resolution.rows[idx].isDuplicate = false
                resolution.rows[idx].selected = true
            }
            csvRefundPurchases = []
        }
        csvResolution = resolution
    }

    func setCSVRefundPurchase(rowId: UUID, purchaseId: UUID?) {
        guard var resolution = csvResolution,
              let index = resolution.negativeRows.firstIndex(where: { $0.id == rowId })
        else { return }
        resolution.negativeRows[index].purchaseId = purchaseId
        csvResolution = resolution
    }

    func eligibleCSVRefundPurchases(
        for row: CSVNegativePreviewRow
    ) -> [Transaction] {
        csvRefundPurchases.filter { purchase in
            guard purchase.refundOfTransactionId == nil,
                  purchase.occurredAt <= row.raw.date
            else { return false }
            let alreadyRefunded = csvRefundPurchases
                .filter { $0.refundOfTransactionId == purchase.id }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return purchase.amount - alreadyRefunded >= abs(row.raw.amount)
        }
    }

    private func loadCSVRefundPurchases(accountId: UUID) async {
        let all = (try? await container.remoteTransactions.loadAll()) ?? []
        csvRefundPurchases = all.filter { $0.accountId == accountId }
    }

    private func applyCSVDedup(
        _ resolution: CSVStatementResolution,
        accountId: UUID
    ) async -> CSVStatementResolution {
        let existing: Set<String> = (try? await container.remoteTransactions.externalIds(forAccount: accountId)) ?? []
        var updated = resolution
        for idx in updated.rows.indices {
            let isDup = existing.contains(updated.rows[idx].externalId)
            updated.rows[idx].isDuplicate = isDup
            // Mesma regra do OFX: duplicada começa desligada (usuário re-marca
            // se quiser forçar re-import).
            updated.rows[idx].selected = !isDup
        }
        return updated
    }

    /// Confirma o preview CSV. Mesmo padrão do OFX: monta drafts em voo +
    /// dispara classificação pré-commit. **Exige conta-cartão selecionada** —
    /// MVP não cria conta no import.
    func confirmCSVImport() async {
        guard phase == .csvReview else { return }
        guard let resolution = csvResolution else { return }

        guard let accountId = resolution.accountId else {
            fail(with: ImportError.accountNotSelected)
            return
        }

        let purchasesToImport = resolution.rows.filter { $0.selected }
        let refundsToImport = resolution.negativeRows.filter {
            $0.raw.kind == .refund && $0.purchaseId != nil
        }
        guard !purchasesToImport.isEmpty || !refundsToImport.isEmpty else {
            fail(with: ImportError.noValidRows)
            return
        }

        let now = Date()
        let batchId = UUID()
        let batch = ImportBatch(
            id: batchId,
            sourceFilename: resolution.sourceFilename,
            accountId: accountId,
            rowCount: purchasesToImport.count + refundsToImport.count,
            importedAt: now,
            createdAt: now,
            updatedAt: now
        )

        var drafts: [TransactionDraft] = purchasesToImport.map { row in
            TransactionDraft(
                id: UUID(),
                accountId: accountId,
                importBatchId: batchId,
                // Compra na fatura é despesa (positivo no CSV após nosso filtro
                // de negativos).
                signedAmount: row.raw.amount,
                occurredAt: row.derived.occurredAt,
                description: row.derived.description,
                notes: row.derived.notes,
                externalId: row.externalId,
                // Categoria do próprio Inter (SUPERMERCADO, TRANSPORTE, BARES…)
                // preservada como contexto para a futura classificação local.
                sourceCategoryHint: row.raw.interCategory
            )
        }
        drafts.append(contentsOf: refundsToImport.compactMap { row in
            guard let purchaseId = row.purchaseId,
                  let purchase = csvRefundPurchases.first(where: { $0.id == purchaseId })
            else { return nil }
            return TransactionDraft(
                id: UUID(),
                accountId: accountId,
                importBatchId: batchId,
                signedAmount: abs(row.raw.amount),
                occurredAt: row.raw.date,
                description: row.raw.description,
                notes: "Estorno importado do CSV Inter",
                externalId: InterCreditCardCSVReader.makeExternalId(
                    date: row.raw.date,
                    description: row.raw.description,
                    amount: abs(row.raw.amount),
                    tipo: "Estorno"
                ),
                refundOfTransactionId: purchase.id
            )
        })

        pendingDrafts = drafts
        pendingBatches = [
            PendingImportBatch(
                batch: batch,
                importFormat: .interCreditCardCSV
            ),
        ]

        startCategorization()
    }

    func cancel() {
        categorizationWaitTask?.cancel()
        categorizationWaitTask = nil
        categorization.cancel()
        clearPendingState()
        phase = .idle
        sourceURL = nil
        ofxDocument = nil
        ofxResolutions = []
        csvResolution = nil
    }

    // MARK: - Confirm OFX (multi-account) → drafts → classificação

    /// Confirma o preview OFX. **Não cria conta nova** — toda statement precisa
    /// estar apontada pra uma conta existente do usuário (auto-detectada ou
    /// escolhida manualmente). Monta drafts (com `signedAmount` original do
    /// OFX) e dispara a classificação pré-commit. Commit acontece em
    /// `finalizeImport()`.
    func confirmOFXImport() async {
        guard phase == .ofxReview else { return }

        // Normaliza upfront pra (resolution, accountId) — uma única checagem
        // de obrigatoriedade, sem precisar reabrir o opcional dentro do loop.
        let resolved: [(resolution: OFXStatementResolution, accountId: UUID)] = ofxResolutions
            .compactMap { resolution in
                resolution.accountId.map { (resolution, $0) }
            }
        guard resolved.count == ofxResolutions.count else {
            fail(with: ImportError.accountNotSelected)
            return
        }

        let now = Date()
        var batches: [PendingImportBatch] = []
        var allDrafts: [TransactionDraft] = []

        for (resolution, accountId) in resolved {
            let toImport = resolution.rows.filter { $0.selected }
            if toImport.isEmpty { continue }

            let batchId = UUID()
            let batch = ImportBatch(
                id: batchId,
                sourceFilename: sourceURL?.lastPathComponent ?? "import.ofx",
                accountId: accountId,
                rowCount: toImport.count,
                importedAt: now,
                createdAt: now,
                updatedAt: now
            )

            let drafts: [TransactionDraft] = toImport.map { row in
                TransactionDraft(
                    id: UUID(),
                    accountId: accountId,
                    importBatchId: batchId,
                    signedAmount: row.derived.amount,
                    occurredAt: row.derived.occurredAt,
                    description: row.derived.description,
                    notes: row.derived.notes,
                    externalId: row.raw.fitid
                )
            }
            allDrafts.append(contentsOf: drafts)
            batches.append(PendingImportBatch(batch: batch, importFormat: .ofx))
        }

        if allDrafts.isEmpty {
            fail(with: ImportError.noValidRows)
            return
        }

        pendingDrafts = allDrafts
        pendingBatches = batches

        startCategorization()
    }

    // MARK: - Finalize (commit atômico)

    /// Commit final do import: usa a categoria escolhida (auto-aprovada ou
    /// corrigida pelo usuário) pra cada draft, monta as `Transaction`s
    /// definitivas com `abs(amount)` e dispara o `commitImport` atômico no
    /// `TransactionRepository`.
    ///
    /// Inclui batches e transactions. Atomicidade total: se qualquer execute
    /// falha, banco fica intocado.
    func finalizeImport() async {
        guard phase == .reviewingCategorization else { return }

        if pendingDrafts.isEmpty {
            fail(with: ImportError.noValidRows)
            return
        }

        phase = .confirming

        do {
            let reviewedRows = pendingDrafts.map { draft in
                let resolved = categorization.resolvedCategory(forTransactionId: draft.id)
                return ReviewedImportRow(
                    draft: draft,
                    categoryId: resolved?.categoryId,
                    subcategoryId: resolved?.subcategoryId
                )
            }

            let input = try Self.buildCommitInput(
                idempotencyKey: makeIdempotencyKey(),
                reviewedRows: reviewedRows,
                pendingBatches: pendingBatches,
                categories: categories
            )
            let result = try await commitReviewedImport(input: input)

            // Limpa estado em voo agora que tudo foi commitado.
            clearPendingState()

            log.import
                .info(
                    "Import concluído: \(result.importedRowCount, privacy: .public) linhas em \(result.batchIds.count, privacy: .public) lote(s)"
                )

            // Confirmação pelo NoticeCenter (toast verde + botão de undo).
            // Substitui o antigo `DoneStepView`: feedback persiste mesmo após o
            // wizard fechar, e o undo agregado ("Desfazer todos os lotes")
            // continua ao alcance de um clique sem precisar passar pela tela
            // de histórico.
            //
            // O closure captura `container.remoteImports` direto (não `self`)
            // porque a sheet vai fechar, o `ImportStore` do wizard vira
            // candidato a dealloc, e o repository é safe pra usar em qualquer
            // lugar — chamada idempotente do ponto de vista do banco.
            //
            // **Não-atômico por lote:** o loop deleta um batch por vez. Se a
            // deleção do N-ésimo falhar, os N-1 anteriores já foram desfeitos
            // e o usuário fica num estado parcial. Aceitável hoje porque (a)
            // o caso comum é 1 lote e (b) cada batch é independente do ponto
            // de vista do dashboard. Quando virar suporte multi-banco
            // rotineiro, mover pro repo (`deleteMany(ids:)` em
            // `writeTransaction`).
            let remoteImports = container.remoteImports
            let duplicateSuffix = if result.duplicateCount > 0 {
                " \(result.duplicateCount) \(result.duplicateCount == 1 ? "duplicada foi ignorada" : "duplicadas foram ignoradas")."
            } else {
                ""
            }
            NoticeCenter.shared.success(
                title: "Importação concluída",
                message: "\(result.importedRowCount) \(result.importedRowCount == 1 ? "transação importada" : "transações importadas") em \(result.batchIds.count) \(result.batchIds.count == 1 ? "lote" : "lotes").\(duplicateSuffix)",
                actions: result.batchIds.isEmpty ? [] : [
                    NoticeCenter.Action(
                        title: result.batchIds.count == 1 ? "Desfazer" : "Desfazer todos",
                        role: .destructive
                    ) {
                        Task {
                            for id in result.batchIds {
                                do {
                                    try await remoteImports.delete(batchId: id)
                                    await Self.notifyImportMutation()
                                } catch {
                                    NoticeCenter.shared.report(error, title: "Falha ao desfazer importação")
                                }
                            }
                        }
                    },
                ]
            )

            phase = .done(batchIds: result.batchIds, rowCount: result.importedRowCount)
        } catch {
            fail(with: error)
        }
    }

    /// Volta da revisão pro preview de origem (OFX ou CSV) — usado pelo botão
    /// "Voltar" da tela de revisão pra ajustar o que vai ser importado antes
    /// de finalizar. Descarta sugestões em memória (próximo confirm refaz a
    /// classificação). Detecta a origem pelo que está populado: csvResolution
    /// presente → CSV; senão → OFX.
    func backToPreviewFromReview() {
        guard phase == .reviewingCategorization || phase == .categorizing else { return }
        categorizationWaitTask?.cancel()
        categorizationWaitTask = nil
        categorization.cancel()
        clearPendingState()
        phase = csvResolution != nil ? .csvReview : .ofxReview
    }

    private func clearPendingState() {
        pendingDrafts = []
        pendingBatches = []
    }

    // MARK: - Undo

    func undo(batchId: UUID) async {
        do {
            try await container.remoteImports.delete(batchId: batchId)
            await refresh()
            await Self.notifyImportMutation()
        } catch {
            NoticeCenter.shared.report(error, title: "Falha ao desfazer importação")
        }
    }

    func commitReviewedImport(input: ImportCommitInput) async throws -> ImportCommitResult {
        let result = try await container.remoteImports.commit(input: input)
        await refresh()
        await Self.notifyImportMutation()
        return result
    }

    static func notifyImportMutation() async {
        await MainActor.run {
            NotificationCenter.default.post(name: didMutateImportsNotification, object: nil)
        }
    }

    static func buildCommitInput(
        idempotencyKey: UUID,
        reviewedRows: [ReviewedImportRow],
        pendingBatches: [PendingImportBatch],
        categories: [Category]
    ) throws -> ImportCommitInput {
        guard let fallbackSlug = categories.rootCategory(slug: "nao-classificado")?.slug else {
            throw ImportError.unclassifiedCategoryMissing
        }

        let rootSlugsById = Dictionary(
            uniqueKeysWithValues: categories
                .filter { $0.parentId == nil }
                .compactMap { category in
                    category.slug.map { (category.id, $0) }
                }
        )

        let batchIds = Set(pendingBatches.map(\.batch.id))
        let rows = reviewedRows
            .filter { batchIds.contains($0.draft.importBatchId) }
            .map { row in
                ImportTransactionCommitInput(
                    transactionId: row.draft.id,
                    batchId: row.draft.importBatchId,
                    categorySlug: row.categoryId.flatMap { rootSlugsById[$0] } ?? fallbackSlug,
                    subcategoryId: row.subcategoryId,
                    amount: abs(row.draft.signedAmount),
                    occurredAt: row.draft.occurredAt,
                    description: row.draft.description,
                    notes: row.draft.notes,
                    externalId: row.draft.externalId,
                    refundOfTransactionId: row.draft.refundOfTransactionId
                )
            }

        return ImportCommitInput(
            idempotencyKey: idempotencyKey,
            batches: pendingBatches.map {
                ImportBatchCommitInput(
                    batchId: $0.batch.id,
                    sourceFilename: $0.batch.sourceFilename,
                    accountId: $0.batch.accountId,
                    importedAt: $0.batch.importedAt,
                    importFormat: $0.importFormat
                )
            },
            rows: rows
        )
    }
}

// MARK: - OFX resolution data structures

/// Estado por `STMTRS`. A partir da Fase 4.5 o import **nunca cria contas** —
/// usuário aponta cada statement pra uma conta existente. `accountId` começa
/// preenchido se o auto-detect (instituição+agência+número) bater com uma
/// conta cadastrada; senão, fica `nil` até o usuário escolher no picker.
struct OFXStatementResolution: Identifiable, Equatable {
    let id = UUID()
    let statement: OFXStatement
    /// Conta de destino — `nil` bloqueia a confirmação até o usuário escolher.
    var accountId: UUID?
    /// `true` se o auto-detect encontrou a conta sozinho; `false` se o usuário
    /// escolheu manualmente ou ainda não escolheu. Usado pra badge na UI.
    var wasAutoDetected: Bool
    /// Banco como o OFX declara (`<FI><ORG>` ou fallback pelo FID). Exibido
    /// no header da Section pra orientar o usuário no picker.
    let ofxBankLabel: String
    /// Identidade da conta como o OFX declara (`accountId · Ag X · cód. Y`).
    let ofxAccountLabel: String
    var rows: [OFXPreviewRow]

    var validRowCount: Int {
        rows.filter { !$0.isDuplicate }.count
    }

    var duplicateRowCount: Int {
        rows.filter(\.isDuplicate).count
    }
}

// MARK: - CSV resolution data structures (Fase 4.5)

/// Estado do preview de fatura CSV (cartão de crédito). É um único batch por
/// arquivo (uma fatura = uma conta). `accountId` precisa estar definido pra
/// confirmar — pré-selecionado quando há uma única conta-cartão cadastrada,
/// senão o usuário escolhe no picker.
struct CSVStatementResolution: Equatable {
    let sourceFilename: String
    var accountId: UUID?
    var rows: [CSVPreviewRow]
    /// Linhas com valor negativo (pagamentos da fatura anterior + estornos)
    /// puladas no parse. Reportadas na UI num disclosure pra o usuário
    /// auditar o que foi filtrado.
    var negativeRows: [CSVNegativePreviewRow]

    var skippedNegativeCount: Int {
        negativeRows.count
    }

    var selectedCount: Int {
        rows.filter(\.selected).count
            + negativeRows.filter { $0.raw.kind == .refund && $0.purchaseId != nil }.count
    }

    var duplicateCount: Int {
        rows.filter(\.isDuplicate).count
    }
}

struct CSVNegativePreviewRow: Identifiable, Equatable {
    let raw: InterCreditCardCSVReader.SkippedRow
    var purchaseId: UUID?

    var id: UUID {
        raw.id
    }
}

struct CSVPreviewRow: Identifiable, Hashable {
    let id = UUID()
    let raw: InterCreditCardCSVReader.Row
    var derived: DerivedTransaction
    /// External ID sintético construído por `InterCreditCardCSVReader.makeExternalId`.
    /// Usado pra dedup contra `transactions.external_id` da conta selecionada.
    let externalId: String
    var isDuplicate: Bool
    var selected: Bool
}

struct PendingImportBatch: Hashable {
    let batch: ImportBatch
    let importFormat: InstitutionImportFormat
}

struct ReviewedImportRow: Hashable {
    let draft: TransactionDraft
    let categoryId: UUID?
    let subcategoryId: UUID?
}

struct OFXPreviewRow: Identifiable, Hashable {
    let id = UUID()
    let raw: OFXTransaction
    var derived: DerivedTransaction
    /// FITID já bate com uma transaction existente da mesma conta. OFX só tem
    /// dois estados de preview hoje: "válida" e "duplicada" — não há `invalid*`
    /// porque o parser OFX já rejeita estruturalmente o que não dá pra
    /// transformar em transação.
    var isDuplicate: Bool
    /// ID da categoria raiz vindo da heurística. Resolvido no `ImportStore`,
    /// não na View, pra evitar passar `database` adiante. Pode ser editado
    /// pelo usuário no preview.
    var categoryId: UUID
    /// Subcategoria opcional. NULL no momento da geração; usuário pode
    /// selecionar uma sub durante o review.
    var subcategoryId: UUID?
    /// Marca por linha: válida → ligada por default; duplicada → desligada
    /// (usuário re-marca pra re-importar).
    var selected: Bool
}
