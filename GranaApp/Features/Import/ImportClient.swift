import ComposableArchitecture
import Foundation

struct ImportSnapshot: Equatable {
    var batches: [ImportBatch]
    var accounts: [Account]
    var institutions: [Institution]
    var bankDetails: [BankAccountDetails]
    var creditCards: [CreditCardDetails]
    var categories: [Category]

    nonisolated static let empty = ImportSnapshot(
        batches: [],
        accounts: [],
        institutions: [],
        bankDetails: [],
        creditCards: [],
        categories: []
    )
}

enum ImportLoadedFile: Equatable {
    case ofx(sourceURL: URL, resolutions: [OFXStatementResolution])
    case csv(sourceURL: URL, resolution: CSVStatementResolution)
}

struct ImportClient {
    var loadSnapshot: @Sendable () async throws -> ImportSnapshot
    var loadFile: @Sendable (_ url: URL, _ snapshot: ImportSnapshot) async throws -> ImportLoadedFile
    var reloadOFXResolution: @Sendable (_ resolution: OFXStatementResolution, _ accountId: UUID?) async
        -> OFXStatementResolution
    var reloadCSVResolution: @Sendable (_ resolution: CSVStatementResolution, _ accountId: UUID?) async
        -> CSVStatementResolution
    var commit: @Sendable (
        _ input: ImportCommitInput,
        _ learnRequest: GranaAIClassificationLearningRequest?
    ) async throws
        -> ImportCommitResult
    var undo: @Sendable (_ batchId: UUID) async throws -> Void

    static func live(container: AppContainer) -> ImportClient {
        ImportClient(
            loadSnapshot: {
                async let institutionsTask = container.institutionCatalog.load()
                async let categoriesTask = container.categoryCatalog.load()
                async let accountsTask = container.remoteAccounts.load()
                async let batchesTask = container.remoteImports.loadBatches()
                let (institutions, categories, accountSnapshot, batches) = try await (
                    institutionsTask,
                    categoriesTask,
                    accountsTask,
                    batchesTask
                )
                return ImportSnapshot(
                    batches: batches,
                    accounts: accountSnapshot.accounts,
                    institutions: institutions,
                    bankDetails: accountSnapshot.bankDetails,
                    creditCards: accountSnapshot.creditCards,
                    categories: categories
                )
            },
            loadFile: { url, snapshot in
                let needsScope = url.startAccessingSecurityScopedResource()
                defer {
                    if needsScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let ext = url.pathExtension.lowercased()
                if ext == "csv" {
                    return try await loadCSV(
                        url: url,
                        snapshot: snapshot,
                        remoteTransactions: container.remoteTransactions
                    )
                }
                return try await loadOFX(
                    url: url,
                    snapshot: snapshot,
                    remoteTransactions: container.remoteTransactions
                )
            },
            reloadOFXResolution: { resolution, accountId in
                await reloadOFXResolution(
                    resolution,
                    accountId: accountId,
                    remoteTransactions: container.remoteTransactions
                )
            },
            reloadCSVResolution: { resolution, accountId in
                await reloadCSVResolution(
                    resolution,
                    accountId: accountId,
                    remoteTransactions: container.remoteTransactions
                )
            },
            commit: { input, learnRequest in
                if let learnRequest {
                    try await container.categorizationFeedback.learnConfirmedClassifications(request: learnRequest)
                }
                return try await container.remoteImports.commit(input: input)
            },
            undo: { batchId in
                try await container.remoteImports.delete(batchId: batchId)
            }
        )
    }
}

extension ImportClient: DependencyKey {
    static let liveValue = ImportClient(
        loadSnapshot: { .empty },
        loadFile: { _, _ in
            .ofx(sourceURL: URL(filePath: "/dev/null"), resolutions: [])
        },
        reloadOFXResolution: { resolution, _ in resolution },
        reloadCSVResolution: { resolution, _ in resolution },
        commit: { _, _ in
            ImportCommitResult(batchIds: [], importedRowCount: 0, duplicateRows: [])
        },
        undo: { _ in }
    )

    static let testValue = ImportClient(
        loadSnapshot: unimplemented("ImportClient.loadSnapshot"),
        loadFile: unimplemented("ImportClient.loadFile"),
        reloadOFXResolution: { _, _ in
            fatalError("ImportClient.reloadOFXResolution")
        },
        reloadCSVResolution: { _, _ in
            fatalError("ImportClient.reloadCSVResolution")
        },
        commit: unimplemented("ImportClient.commit"),
        undo: unimplemented("ImportClient.undo")
    )
}

extension DependencyValues {
    var importClient: ImportClient {
        get { self[ImportClient.self] }
        set { self[ImportClient.self] = newValue }
    }
}

enum ImportCommitBuilder {
    nonisolated static func buildInput(
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
                    originOccurredAt: row.draft.originOccurredAt,
                    purchaseType: row.draft.purchaseType,
                    installmentIndex: row.draft.installmentIndex,
                    installmentCount: row.draft.installmentCount,
                    description: row.draft.description,
                    notes: row.draft.notes,
                    externalId: row.draft.externalId
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

    nonisolated static func buildLearnRequest(
        suggestions: [CategorizationSuggestion],
        categories: [Category]
    ) throws -> GranaAIClassificationLearningRequest? {
        try GranaAIFeedbackService.buildLearningRequest(
            suggestions: suggestions,
            categories: categories
        )
    }
}

private extension ImportClient {
    static func loadOFX(
        url: URL,
        snapshot: ImportSnapshot,
        remoteTransactions: any TransactionRemoteRepositoryProtocol
    ) async throws -> ImportLoadedFile {
        let reader = OFXReader()
        let document = try reader.read(from: url)
        guard let unclassified = snapshot.categories.rootCategory(slug: "nao-classificado") else {
            throw ImportError.unclassifiedCategoryMissing
        }
        let heuristic = OFXCategoryHeuristic(
            roots: .init(
                unclassified: unclassified.id,
                transfers: snapshot.categories.rootCategory(slug: "transferencias")?.id,
                income: snapshot.categories.rootCategory(slug: "renda-e-pagamentos")?.id
            )
        )

        var resolutions: [OFXStatementResolution] = []
        resolutions.reserveCapacity(document.statements.count)

        for statement in document.statements {
            let matchedAccountId = autoDetectAccountId(
                for: statement,
                snapshot: snapshot
            )
            let existingExternalIds: Set<String>
            if let matchedAccountId {
                existingExternalIds = (try? await remoteTransactions.externalIds(forAccount: matchedAccountId)) ?? []
            } else {
                existingExternalIds = []
            }

            resolutions.append(
                OFXStatementResolution(
                    statement: statement,
                    accountId: matchedAccountId,
                    wasAutoDetected: matchedAccountId != nil,
                    ofxBankLabel: ofxBankLabel(for: statement, institutions: snapshot.institutions),
                    ofxAccountLabel: ofxAccountLabel(for: statement),
                    rows: buildOFXRows(
                        statement: statement,
                        existingExternalIds: existingExternalIds,
                        heuristic: heuristic
                    )
                )
            )
        }

        guard !resolutions.allSatisfy(\.rows.isEmpty) else {
            throw ImportError.noValidRows
        }

        return .ofx(sourceURL: url, resolutions: resolutions)
    }

    static func loadCSV(
        url: URL,
        snapshot: ImportSnapshot,
        remoteTransactions: any TransactionRemoteRepositoryProtocol
    ) async throws -> ImportLoadedFile {
        let reader = InterCreditCardCSVReader()
        let statement = try reader.read(from: url)
        let creditCardAccounts = snapshot.accounts.filter { account in
            guard account.type == .creditCard,
                  !account.archived,
                  let institutionId = account.institutionId,
                  let institution = snapshot.institutions.first(where: { $0.id == institutionId })
            else { return false }
            return institution.capabilities.supports(.interCreditCardCSV)
        }
        guard !creditCardAccounts.isEmpty else {
            throw ImportError.noCreditCardAccount
        }

        let initialAccountId = creditCardAccounts.count == 1 ? creditCardAccounts.first?.id : nil
        var resolution = CSVStatementResolution(
            sourceFilename: url.lastPathComponent,
            accountId: initialAccountId,
            rows: statement.rows.map { raw in
                let occurredAt = InterCreditCardCSVReader.competenceDate(for: raw)
                return CSVPreviewRow(
                    raw: raw,
                    derived: DerivedTransaction(
                        occurredAt: occurredAt,
                        amount: raw.amount,
                        description: raw.description,
                        notes: "\(raw.tipo) · \(raw.interCategory)"
                    ),
                    externalId: InterCreditCardCSVReader.makeExternalId(
                        date: raw.date,
                        description: raw.description,
                        amount: raw.amount,
                        purchaseType: raw.purchaseType,
                        installmentIndex: raw.installmentIndex,
                        installmentCount: raw.installmentCount
                    ),
                    isDuplicate: false,
                    selected: true
                )
            },
            negativeRows: statement.skippedNegatives.map {
                CSVNegativePreviewRow(raw: $0, selected: false)
            }
        )

        if let initialAccountId {
            resolution = await reloadCSVResolution(
                resolution,
                accountId: initialAccountId,
                remoteTransactions: remoteTransactions
            )
        }

        return .csv(
            sourceURL: url,
            resolution: resolution
        )
    }

    static func reloadOFXResolution(
        _ resolution: OFXStatementResolution,
        accountId: UUID?,
        remoteTransactions: any TransactionRemoteRepositoryProtocol
    ) async -> OFXStatementResolution {
        var resolution = resolution
        resolution.accountId = accountId
        resolution.wasAutoDetected = false

        let existingExternalIds: Set<String>
        if let accountId {
            existingExternalIds = (try? await remoteTransactions.externalIds(forAccount: accountId)) ?? []
        } else {
            existingExternalIds = []
        }

        for rowIndex in resolution.rows.indices {
            let fitid = resolution.rows[rowIndex].raw.fitid
            let wasDuplicate = resolution.rows[rowIndex].isDuplicate
            let isDuplicate = existingExternalIds.contains(fitid)
            resolution.rows[rowIndex].isDuplicate = isDuplicate
            if wasDuplicate != isDuplicate {
                resolution.rows[rowIndex].selected = !isDuplicate
            }
        }

        return resolution
    }

    static func reloadCSVResolution(
        _ resolution: CSVStatementResolution,
        accountId: UUID?,
        remoteTransactions: any TransactionRemoteRepositoryProtocol
    ) async -> CSVStatementResolution {
        var resolution = resolution
        resolution.accountId = accountId

        guard let accountId else {
            for index in resolution.rows.indices {
                resolution.rows[index].isDuplicate = false
                resolution.rows[index].selected = true
            }
            for index in resolution.negativeRows.indices {
                resolution.negativeRows[index].selected = false
            }
            return resolution
        }

        let existing = (try? await remoteTransactions.externalIds(forAccount: accountId)) ?? []
        for index in resolution.rows.indices {
            let isDuplicate = existing.contains(resolution.rows[index].externalId)
            resolution.rows[index].isDuplicate = isDuplicate
            resolution.rows[index].selected = !isDuplicate
        }

        for index in resolution.negativeRows.indices {
            resolution.negativeRows[index].selected = false
        }
        return resolution
    }

    static func buildOFXRows(
        statement: OFXStatement,
        existingExternalIds: Set<String>,
        heuristic: OFXCategoryHeuristic
    ) -> [OFXPreviewRow] {
        statement.transactions.map { transaction in
            let isDuplicate = existingExternalIds.contains(transaction.fitid)
            return OFXPreviewRow(
                raw: transaction,
                derived: DerivedTransaction(
                    occurredAt: transaction.datePosted,
                    amount: transaction.amount,
                    description: transaction.displayDescription,
                    notes: transaction.memo
                ),
                isDuplicate: isDuplicate,
                categoryId: heuristic.categoryId(for: transaction),
                subcategoryId: nil,
                selected: !isDuplicate
            )
        }
    }

    static func autoDetectAccountId(
        for statement: OFXStatement,
        snapshot: ImportSnapshot
    ) -> UUID? {
        let code = statement.account.bankId
        guard let institution = snapshot.institutions.institution(code: code, supporting: .ofx) else {
            return nil
        }

        return snapshot.accounts.first { account in
            guard account.institutionId == institution.id,
                  let details = snapshot.bankDetails.first(where: { $0.accountId == account.id })
            else { return false }
            return details.accountNumber == statement.account.accountId
                && details.branchId == statement.account.branchId
        }?.id
    }

    static func ofxBankLabel(
        for statement: OFXStatement,
        institutions: [Institution]
    ) -> String {
        if let org = statement.institutionHeader.organization, !org.isEmpty {
            return org
        }
        if let institution = institutions.institution(code: statement.account.bankId) {
            return institution.name
        }
        return statement.account.bankId
    }

    static func ofxAccountLabel(for statement: OFXStatement) -> String {
        var parts = [statement.account.accountId]
        if let branch = statement.account.branchId, !branch.isEmpty {
            parts.append("Ag \(branch)")
        }
        parts.append("cód. \(statement.account.bankId)")
        return parts.joined(separator: " · ")
    }
}
