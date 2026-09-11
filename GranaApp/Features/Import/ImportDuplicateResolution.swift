import Foundation

enum ImportDuplicateResolution {
    static func reloadOFXResolution(
        _ resolution: OFXStatementResolution,
        accountId: UUID?
    ) async -> OFXStatementResolution {
        var resolution = resolution
        resolution.accountId = accountId
        resolution.wasAutoDetected = false

        for rowIndex in resolution.rows.indices {
            let wasDuplicate = resolution.rows[rowIndex].isDuplicate
            resolution.rows[rowIndex].isDuplicate = false
            if wasDuplicate {
                resolution.rows[rowIndex].selected = true
            }
        }

        return resolution
    }

    static func reloadCSVResolution(
        _ resolution: CSVStatementResolution,
        accountId: UUID?
    ) async -> CSVStatementResolution {
        var resolution = resolution
        resolution.accountId = accountId

        for index in resolution.rows.indices {
            let wasDuplicate = resolution.rows[index].isDuplicate
            resolution.rows[index].isDuplicate = false
            if wasDuplicate {
                resolution.rows[index].selected = true
            }
        }

        for index in resolution.negativeRows.indices {
            resolution.negativeRows[index].selected = false
        }
        return resolution
    }
}
