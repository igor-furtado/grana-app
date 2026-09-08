import Foundation

enum ImportDuplicateResolution {
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
}
