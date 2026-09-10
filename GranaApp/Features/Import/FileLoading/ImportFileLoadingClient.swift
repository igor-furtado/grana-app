import ComposableArchitecture
import Foundation

struct ImportFileLoadingClient {
    var loadFile: @Sendable (_ url: URL, _ snapshot: ImportSnapshot) async throws -> ImportLoadedFile

    static func live(container: AppContainer) -> ImportFileLoadingClient {
        ImportFileLoadingClient(
            loadFile: { url, snapshot in
                let needsScope = url.startAccessingSecurityScopedResource()
                defer {
                    if needsScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let ext = url.pathExtension.lowercased()
                if ext == "csv" {
                    return try await ImportFileLoadingOperations.loadCSV(
                        url: url,
                        snapshot: snapshot,
                        remoteTransactions: container.remoteTransactions
                    )
                }
                return try await ImportFileLoadingOperations.loadOFX(
                    url: url,
                    snapshot: snapshot,
                    remoteTransactions: container.remoteTransactions
                )
            }
        )
    }
}

extension ImportFileLoadingClient: DependencyKey {
    static let liveValue = ImportFileLoadingClient(
        loadFile: { _, _ in
            .ofx(sourceURL: URL(filePath: "/dev/null"), resolutions: [])
        }
    )

    static let testValue = ImportFileLoadingClient(
        loadFile: unimplemented("ImportFileLoadingClient.loadFile")
    )
}

extension DependencyValues {
    var importFileLoadingClient: ImportFileLoadingClient {
        get { self[ImportFileLoadingClient.self] }
        set { self[ImportFileLoadingClient.self] = newValue }
    }
}

private enum ImportFileLoadingOperations {
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
            resolution = await ImportDuplicateResolution.reloadCSVResolution(
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
                    notes: transaction.displayNotes
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
