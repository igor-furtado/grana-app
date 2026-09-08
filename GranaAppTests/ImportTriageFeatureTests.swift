import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("ImportTriageFeature")
struct ImportTriageFeatureTests {
    @Test("Triagem OFX confirmada delega payload conceitual")
    func ofxTriageConfirmationDelegatesConfirmedTriage() async {
        let resolution = makeOFXResolution(accountId: UUID())
        let store = TestStore(
            initialState: ImportTriageFeature.State(
                sourceFilename: "extrato.ofx",
                content: .ofx(OFXTriageFeature.State(
                    resolutions: [resolution],
                    accounts: [],
                    institutions: [],
                    bankDetails: [],
                    creditCards: []
                ))
            )
        ) {
            ImportTriageFeature()
        }

        await store.send(.advanceButtonTapped)
        await store.receive(.delegate(.confirmed(.ofx(
            sourceFilename: "extrato.ofx",
            resolutions: [resolution]
        ))))
    }

    @Test("Triagem CSV confirmada delega payload conceitual")
    func csvTriageConfirmationDelegatesConfirmedTriage() async {
        let resolution = makeCSVResolution(accountId: UUID())
        let store = TestStore(
            initialState: ImportTriageFeature.State(
                sourceFilename: "fatura.csv",
                content: .csv(CSVTriageFeature.State(
                    resolution: resolution,
                    accounts: [],
                    institutions: [],
                    bankDetails: [],
                    creditCards: []
                ))
            )
        ) {
            ImportTriageFeature()
        }

        await store.send(.advanceButtonTapped)
        await store.receive(.delegate(.confirmed(.interCreditCardCSV(
            sourceFilename: "fatura.csv",
            resolution: resolution
        ))))
    }

    @Test("Wizard carrega OFX como fase única de triagem")
    func wizardLoadsOFXIntoTriagePhase() async {
        let fileURL = URL(fileURLWithPath: "/tmp/extrato.ofx")
        let resolution = makeOFXResolution(accountId: nil)
        let store = TestStore(initialState: ImportWizardFeature.State()) {
            ImportWizardFeature()
        }

        await store.send(.fileLoaded(.success(.ofx(
            sourceURL: fileURL,
            resolutions: [resolution]
        )))) {
            $0.sourceURL = fileURL
            $0.triage = ImportTriageFeature.State(
                sourceFilename: "extrato.ofx",
                content: .ofx(OFXTriageFeature.State(
                    resolutions: [resolution],
                    accounts: [],
                    institutions: [],
                    bankDetails: [],
                    creditCards: []
                ))
            )
            $0.phase = .triage
        }
    }

    @Test("Wizard carrega CSV como fase única de triagem")
    func wizardLoadsCSVIntoTriagePhase() async {
        let fileURL = URL(fileURLWithPath: "/tmp/fatura.csv")
        let resolution = makeCSVResolution(accountId: nil)
        let store = TestStore(initialState: ImportWizardFeature.State()) {
            ImportWizardFeature()
        }

        await store.send(.fileLoaded(.success(.csv(
            sourceURL: fileURL,
            resolution: resolution
        )))) {
            $0.sourceURL = fileURL
            $0.triage = ImportTriageFeature.State(
                sourceFilename: "fatura.csv",
                content: .csv(CSVTriageFeature.State(
                    resolution: resolution,
                    accounts: [],
                    institutions: [],
                    bankDetails: [],
                    creditCards: []
                ))
            )
            $0.phase = .triage
        }
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

    private func makeCSVResolution(accountId: UUID?) -> CSVStatementResolution {
        let date = Date(timeIntervalSince1970: 1_787_970_600)
        let raw = InterCreditCardCSVReader.Row(
            date: date,
            description: "Mercado",
            interCategory: "SUPERMERCADO",
            tipo: "Compra à vista",
            purchaseType: .cash,
            installmentIndex: nil,
            installmentCount: nil,
            amount: 30
        )
        return CSVStatementResolution(
            sourceFilename: "fatura.csv",
            accountId: accountId,
            rows: [
                CSVPreviewRow(
                    raw: raw,
                    derived: DerivedTransaction(
                        occurredAt: date,
                        amount: 30,
                        description: "Mercado",
                        notes: nil
                    ),
                    externalId: "csv-1",
                    isDuplicate: false,
                    selected: true
                ),
            ],
            negativeRows: []
        )
    }
}
