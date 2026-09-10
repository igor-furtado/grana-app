import ComposableArchitecture
import Foundation

struct ImportPlanningClient {
    var makePendingPlan: @Sendable (
        _ triage: ConfirmedImportTriage,
        _ context: ImportPlanningContext
    ) throws -> PendingImportPlan
}

enum ConfirmedImportTriage: Equatable {
    case ofx(sourceFilename: String, resolutions: [OFXStatementResolution])
    case interCreditCardCSV(sourceFilename: String, resolution: CSVStatementResolution)
}

struct ImportPlanningContext {
    var now: Date
    var makeID: () -> UUID
}

struct PendingImportPlan: Equatable {
    var batches: [PendingImportBatch]
    var drafts: [TransactionDraft]
    var impact: ImportPlanImpact
}

struct ImportPlanImpact: Equatable {
    var importedRowCount: Int
    var skippedDuplicateRowCount: Int
    var skippedDeselectedRowCount: Int
    var statementBalanceDraftCount: Int
}

extension ImportPlanningClient: DependencyKey {
    static let liveValue = ImportPlanningClient { triage, context in
        switch triage {
        case let .ofx(sourceFilename, resolutions):
            try Self.makeOFXPendingPlan(
                sourceFilename: sourceFilename,
                resolutions: resolutions,
                context: context
            )

        case let .interCreditCardCSV(sourceFilename, resolution):
            try Self.makeCSVPendingPlan(
                sourceFilename: sourceFilename,
                resolution: resolution,
                context: context
            )
        }
    }

    static let testValue = ImportPlanningClient(
        makePendingPlan: unimplemented("ImportPlanningClient.makePendingPlan")
    )
}

extension DependencyValues {
    var importPlanningClient: ImportPlanningClient {
        get { self[ImportPlanningClient.self] }
        set { self[ImportPlanningClient.self] = newValue }
    }
}

private extension ImportPlanningClient {
    nonisolated static func makeOFXPendingPlan(
        sourceFilename: String,
        resolutions: [OFXStatementResolution],
        context: ImportPlanningContext
    ) throws -> PendingImportPlan {
        let resolved = resolutions.compactMap { resolution in
            resolution.accountId.map { (resolution, $0) }
        }
        guard resolved.count == resolutions.count else {
            throw ImportError.accountNotSelected
        }

        var pendingBatches: [PendingImportBatch] = []
        var pendingDrafts: [TransactionDraft] = []
        var skippedDuplicateRowCount = 0
        var skippedDeselectedRowCount = 0

        for (resolution, accountId) in resolved {
            let selectedRows = resolution.rows.filter { row in
                if row.isDuplicate {
                    skippedDuplicateRowCount += 1
                    return false
                }
                if !row.selected {
                    skippedDeselectedRowCount += 1
                    return false
                }
                return true
            }
            if selectedRows.isEmpty {
                continue
            }

            let batchId = context.makeID()
            let batch = ImportBatch(
                id: batchId,
                sourceFilename: sourceFilename,
                accountId: accountId,
                rowCount: selectedRows.count,
                importedAt: context.now,
                createdAt: context.now,
                updatedAt: context.now
            )
            pendingBatches.append(PendingImportBatch(batch: batch, importFormat: .ofx))
            pendingDrafts.append(contentsOf: selectedRows.map { row in
                TransactionDraft(
                    id: context.makeID(),
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
            throw ImportError.noValidRows
        }

        return PendingImportPlan(
            batches: pendingBatches,
            drafts: pendingDrafts,
            impact: ImportPlanImpact(
                importedRowCount: pendingDrafts.count,
                skippedDuplicateRowCount: skippedDuplicateRowCount,
                skippedDeselectedRowCount: skippedDeselectedRowCount,
                statementBalanceDraftCount: 0
            )
        )
    }

    nonisolated static func makeCSVPendingPlan(
        sourceFilename: String,
        resolution: CSVStatementResolution,
        context: ImportPlanningContext
    ) throws -> PendingImportPlan {
        guard let accountId = resolution.accountId else {
            throw ImportError.accountNotSelected
        }

        let purchasesToImport = resolution.rows.filter { $0.selected && !$0.isDuplicate }
        let balancesToImport = resolution.negativeRows.filter {
            $0.raw.kind == .balance && $0.selected
        }
        let paymentsToImport = resolution.negativeRows.filter {
            $0.raw.kind == .payment && $0.selected
        }
        guard !purchasesToImport.isEmpty || !balancesToImport.isEmpty || !paymentsToImport.isEmpty else {
            throw ImportError.noValidRows
        }

        let skippedDuplicateRowCount = resolution.rows.filter(\.isDuplicate).count
        let skippedDeselectedRowCount = resolution.rows.filter { !$0.isDuplicate && !$0.selected }.count
            + resolution.negativeRows.filter { !$0.selected }.count
        let batchId = context.makeID()
        let batch = ImportBatch(
            id: batchId,
            sourceFilename: sourceFilename,
            accountId: accountId,
            rowCount: purchasesToImport.count + balancesToImport.count + paymentsToImport.count,
            importedAt: context.now,
            createdAt: context.now,
            updatedAt: context.now
        )

        var drafts = purchasesToImport.map { row in
            TransactionDraft(
                id: context.makeID(),
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
                id: context.makeID(),
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
        drafts.append(contentsOf: paymentsToImport.map { row in
            TransactionDraft(
                id: context.makeID(),
                accountId: accountId,
                importBatchId: batchId,
                signedAmount: abs(row.raw.amount),
                occurredAt: row.raw.date,
                originOccurredAt: row.raw.date,
                description: row.raw.description,
                notes: "Pagamento importado do CSV Inter",
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

        return PendingImportPlan(
            batches: [
                PendingImportBatch(batch: batch, importFormat: .interCreditCardCSV),
            ],
            drafts: drafts,
            impact: ImportPlanImpact(
                importedRowCount: drafts.count,
                skippedDuplicateRowCount: skippedDuplicateRowCount,
                skippedDeselectedRowCount: skippedDeselectedRowCount,
                statementBalanceDraftCount: balancesToImport.count
            )
        )
    }
}
