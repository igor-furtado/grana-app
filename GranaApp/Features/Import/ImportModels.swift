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
