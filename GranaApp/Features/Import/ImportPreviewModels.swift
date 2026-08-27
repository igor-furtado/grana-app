import Foundation

enum ImportFeatureConfiguration {
    nonisolated static let supportedExtensions: Set<String> = ["ofx", "csv"]
}

/// Estado por `STMTRS`. A importação nunca cria contas: cada extrato precisa
/// apontar para uma conta existente do usuário.
struct OFXStatementResolution: Identifiable, Equatable {
    let id = UUID()
    let statement: OFXStatement
    var accountId: UUID?
    var wasAutoDetected: Bool
    let ofxBankLabel: String
    let ofxAccountLabel: String
    var rows: [OFXPreviewRow]

    var validRowCount: Int {
        rows.filter { !$0.isDuplicate }.count
    }

    var duplicateRowCount: Int {
        rows.filter(\.isDuplicate).count
    }
}

/// Estado do preview de fatura CSV (cartão de crédito). É um único batch por
/// arquivo; a conta-cartão de destino precisa existir.
struct CSVStatementResolution: Equatable {
    let sourceFilename: String
    var accountId: UUID?
    var rows: [CSVPreviewRow]
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
    var isDuplicate: Bool
    var categoryId: UUID
    var subcategoryId: UUID?
    var selected: Bool
}
