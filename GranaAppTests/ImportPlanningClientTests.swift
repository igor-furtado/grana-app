import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("ImportPlanningClient")
struct ImportPlanningClientTests {
    @Test("CSV confirmado vira plano com lote único, compra e saldo da fatura")
    func csvTriageBuildsSingleBatchWithPurchaseAndStatementBalance() throws {
        let accountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let batchId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let purchaseDraftId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
        let balanceDraftId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000004"))
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let purchaseDate = Date(timeIntervalSince1970: 1_787_000_000)
        let balanceDate = Date(timeIntervalSince1970: 1_787_086_400)

        let resolution = CSVStatementResolution(
            sourceFilename: "fatura-inter.csv",
            accountId: accountId,
            rows: [
                CSVPreviewRow(
                    raw: InterCreditCardCSVReader.Row(
                        date: purchaseDate,
                        description: "RESTAURANTE",
                        interCategory: "ALIMENTACAO",
                        tipo: "Parcela 2/3",
                        purchaseType: .installment,
                        installmentIndex: 2,
                        installmentCount: 3,
                        amount: decimal("129.90")
                    ),
                    derived: DerivedTransaction(
                        occurredAt: balanceDate,
                        amount: decimal("129.90"),
                        description: "Restaurante",
                        notes: "Parcela 2/3 · ALIMENTACAO"
                    ),
                    externalId: "csv-purchase-1",
                    isDuplicate: false,
                    selected: true
                ),
            ],
            negativeRows: [
                CSVNegativePreviewRow(
                    raw: InterCreditCardCSVReader.SkippedRow(
                        date: balanceDate,
                        description: "BONUS INTER",
                        amount: decimal("-18.02"),
                        kind: .balance
                    ),
                    selected: true
                ),
                CSVNegativePreviewRow(
                    raw: InterCreditCardCSVReader.SkippedRow(
                        date: balanceDate,
                        description: "PAGAMENTO FATURA",
                        amount: decimal("-120"),
                        kind: .payment
                    ),
                    selected: true
                ),
            ]
        )

        let plan = try ImportPlanningClient.liveValue.makePendingPlan(
            .interCreditCardCSV(sourceFilename: "fatura-inter.csv", resolution: resolution),
            .init(now: now, makeID: makeIDGenerator([batchId, purchaseDraftId, balanceDraftId]))
        )

        #expect(plan.batches.count == 1)
        #expect(plan.batches.first?.batch.id == batchId)
        #expect(plan.batches.first?.batch.sourceFilename == "fatura-inter.csv")
        #expect(plan.batches.first?.batch.accountId == accountId)
        #expect(plan.batches.first?.batch.rowCount == 2)
        #expect(plan.batches.first?.batch.importedAt == now)
        #expect(plan.batches.first?.importFormat == .interCreditCardCSV)

        #expect(plan.drafts.count == 2)
        #expect(plan.drafts[0].id == purchaseDraftId)
        #expect(plan.drafts[0].accountId == accountId)
        #expect(plan.drafts[0].importBatchId == batchId)
        #expect(plan.drafts[0].signedAmount == decimal("129.90"))
        #expect(plan.drafts[0].occurredAt == balanceDate)
        #expect(plan.drafts[0].originOccurredAt == purchaseDate)
        #expect(plan.drafts[0].purchaseType == .installment)
        #expect(plan.drafts[0].installmentIndex == 2)
        #expect(plan.drafts[0].installmentCount == 3)
        #expect(plan.drafts[0].description == "Restaurante")
        #expect(plan.drafts[0].notes == "Parcela 2/3 · ALIMENTACAO")
        #expect(plan.drafts[0].externalId == "csv-purchase-1")
        #expect(plan.drafts[0].sourceCategoryHint == "ALIMENTACAO")

        #expect(plan.drafts[1].id == balanceDraftId)
        #expect(plan.drafts[1].signedAmount == decimal("18.02"))
        #expect(plan.drafts[1].occurredAt == balanceDate)
        #expect(plan.drafts[1].originOccurredAt == balanceDate)
        #expect(plan.drafts[1].description == "BONUS INTER")
        #expect(plan.drafts[1].notes == "Saldo importado do CSV Inter")
        #expect(plan.impact.importedRowCount == 2)
        #expect(plan.impact.statementBalanceDraftCount == 1)
    }

    @Test("OFX confirmado cria um lote por extrato com linhas selecionadas")
    func ofxTriageBuildsOneBatchPerSelectedStatement() throws {
        let firstAccountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000011"))
        let secondAccountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000012"))
        let firstBatchId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000013"))
        let firstDraftId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000014"))
        let secondBatchId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000015"))
        let secondDraftId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000016"))
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let firstDate = Date(timeIntervalSince1970: 1_787_000_000)
        let secondDate = Date(timeIntervalSince1970: 1_787_086_400)

        let plan = try ImportPlanningClient.liveValue.makePendingPlan(
            .ofx(
                sourceFilename: "extratos.ofx",
                resolutions: [
                    makeOFXResolution(
                        accountId: firstAccountId,
                        fitid: "FIT-1",
                        occurredAt: firstDate,
                        amount: Decimal(-42),
                        selected: true
                    ),
                    makeOFXResolution(
                        accountId: secondAccountId,
                        fitid: "FIT-2",
                        occurredAt: secondDate,
                        amount: Decimal(120),
                        selected: true
                    ),
                ]
            ),
            .init(now: now, makeID: makeIDGenerator([
                firstBatchId,
                firstDraftId,
                secondBatchId,
                secondDraftId,
            ]))
        )

        #expect(plan.batches.map(\.batch.id) == [firstBatchId, secondBatchId])
        #expect(plan.batches.map(\.batch.accountId) == [firstAccountId, secondAccountId])
        #expect(plan.batches.map(\.batch.rowCount) == [1, 1])
        #expect(plan.batches.map(\.importFormat) == [.ofx, .ofx])
        #expect(plan.drafts.map(\.id) == [firstDraftId, secondDraftId])
        #expect(plan.drafts.map(\.accountId) == [firstAccountId, secondAccountId])
        #expect(plan.drafts.map(\.importBatchId) == [firstBatchId, secondBatchId])
        #expect(plan.drafts.map(\.externalId) == ["FIT-1", "FIT-2"])
        #expect(plan.drafts.map(\.signedAmount) == [Decimal(-42), Decimal(120)])
        #expect(plan.drafts.map(\.originOccurredAt) == [firstDate, secondDate])
        #expect(plan.impact.importedRowCount == 2)
    }

    @Test("Triagem sem conta ou sem linhas selecionadas falha antes da classificação")
    func invalidTriageFailsBeforeClassification() throws {
        do {
            try ImportPlanningClient.liveValue.makePendingPlan(
                .ofx(sourceFilename: "extrato.ofx", resolutions: [
                    makeOFXResolution(accountId: nil, fitid: "FIT-1", selected: true),
                ]),
                .init(now: Date(), makeID: UUID.init)
            )
            Issue.record("Expected accountNotSelected")
        } catch ImportError.accountNotSelected {
        } catch {
            Issue.record("Expected accountNotSelected, got \(error)")
        }

        do {
            try ImportPlanningClient.liveValue.makePendingPlan(
                .ofx(sourceFilename: "extrato.ofx", resolutions: [
                    makeOFXResolution(accountId: UUID(), fitid: "FIT-1", selected: false),
                ]),
                .init(now: Date(), makeID: UUID.init)
            )
            Issue.record("Expected noValidRows")
        } catch ImportError.noValidRows {
        } catch {
            Issue.record("Expected noValidRows, got \(error)")
        }
    }

    @Test("Linhas duplicadas ou desmarcadas não entram no plano")
    func duplicateAndDeselectedRowsDoNotBecomeDrafts() throws {
        let accountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000021"))
        let batchId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000022"))
        let draftId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000023"))

        let plan = try ImportPlanningClient.liveValue.makePendingPlan(
            .ofx(sourceFilename: "extrato.ofx", resolutions: [
                makeOFXResolution(accountId: accountId, fitid: "FIT-1", amount: Decimal(-10), selected: true),
                makeOFXResolution(
                    accountId: accountId,
                    fitid: "FIT-2",
                    amount: Decimal(-20),
                    selected: true,
                    isDuplicate: true
                ),
                makeOFXResolution(accountId: accountId, fitid: "FIT-3", amount: Decimal(-30), selected: false),
            ]),
            .init(now: Date(), makeID: makeIDGenerator([batchId, draftId]))
        )

        #expect(plan.batches.count == 1)
        #expect(plan.batches.first?.batch.rowCount == 1)
        #expect(plan.drafts.map(\.externalId) == ["FIT-1"])
        #expect(plan.impact.importedRowCount == 1)
        #expect(plan.impact.skippedDuplicateRowCount == 1)
        #expect(plan.impact.skippedDeselectedRowCount == 1)
    }

    @Test("CSV ignora compras duplicadas ou desmarcadas")
    func csvDuplicateAndDeselectedPurchasesDoNotBecomeDrafts() throws {
        let accountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000031"))
        let batchId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000032"))
        let draftId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000033"))
        let purchaseDate = Date(timeIntervalSince1970: 1_787_000_000)

        let resolution = CSVStatementResolution(
            sourceFilename: "fatura-inter.csv",
            accountId: accountId,
            rows: [
                makeCSVRow(
                    date: purchaseDate,
                    description: "MERCADO",
                    externalId: "csv-1",
                    amount: decimal("45.50"),
                    selected: true
                ),
                makeCSVRow(
                    date: purchaseDate,
                    description: "DUPLICADA",
                    externalId: "csv-2",
                    amount: decimal("10"),
                    isDuplicate: true,
                    selected: true
                ),
                makeCSVRow(
                    date: purchaseDate,
                    description: "DESMARCADA",
                    externalId: "csv-3",
                    amount: decimal("20"),
                    selected: false
                ),
            ],
            negativeRows: []
        )

        let plan = try ImportPlanningClient.liveValue.makePendingPlan(
            .interCreditCardCSV(sourceFilename: "fatura-inter.csv", resolution: resolution),
            .init(now: Date(), makeID: makeIDGenerator([batchId, draftId]))
        )

        #expect(plan.batches.count == 1)
        #expect(plan.batches.first?.batch.rowCount == 1)
        #expect(plan.drafts.map(\.externalId) == ["csv-1"])
        #expect(plan.drafts.map(\.description) == ["Mercado"])
        #expect(plan.impact.importedRowCount == 1)
        #expect(plan.impact.skippedDuplicateRowCount == 1)
        #expect(plan.impact.skippedDeselectedRowCount == 1)
    }

    private func makeOFXResolution(
        accountId: UUID?,
        fitid: String,
        occurredAt: Date = Date(timeIntervalSince1970: 1_787_000_000),
        amount: Decimal = Decimal(-10),
        selected: Bool,
        isDuplicate: Bool = false
    ) -> OFXStatementResolution {
        let transaction = OFXTransaction(
            trnType: amount < 0 ? "DEBIT" : "CREDIT",
            datePosted: occurredAt,
            amount: amount,
            fitid: fitid,
            name: "Linha \(fitid)",
            memo: "Memo \(fitid)",
            checkNumber: nil,
            refNumber: nil
        )
        return OFXStatementResolution(
            statement: OFXStatement(
                currency: "BRL",
                institutionHeader: OFXInstitutionHeader(organization: "Banco", fid: "001"),
                account: OFXAccountKey(bankId: "001", branchId: "0001", accountId: "12345"),
                transactions: [transaction],
                balance: nil
            ),
            accountId: accountId,
            wasAutoDetected: accountId != nil,
            ofxBankLabel: "Banco",
            ofxAccountLabel: "12345 · Ag 0001 · cód. 001",
            rows: [
                OFXPreviewRow(
                    raw: transaction,
                    derived: DerivedTransaction(
                        occurredAt: occurredAt,
                        amount: amount,
                        description: "Linha \(fitid)",
                        notes: "Memo \(fitid)"
                    ),
                    isDuplicate: isDuplicate,
                    categoryId: UUID(),
                    subcategoryId: nil,
                    selected: selected
                ),
            ]
        )
    }

    private func makeCSVRow(
        date: Date,
        description: String,
        externalId: String,
        amount: Decimal,
        isDuplicate: Bool = false,
        selected: Bool
    ) -> CSVPreviewRow {
        CSVPreviewRow(
            raw: InterCreditCardCSVReader.Row(
                date: date,
                description: description,
                interCategory: "GERAL",
                tipo: "Compra",
                purchaseType: .oneTime,
                installmentIndex: nil,
                installmentCount: nil,
                amount: amount
            ),
            derived: DerivedTransaction(
                occurredAt: date,
                amount: amount,
                description: description.capitalized,
                notes: "GERAL"
            ),
            externalId: externalId,
            isDuplicate: isDuplicate,
            selected: selected
        )
    }

    private func makeIDGenerator(_ ids: [UUID]) -> () -> UUID {
        final class Box {
            var ids: [UUID]

            init(ids: [UUID]) {
                self.ids = ids
            }
        }

        let box = Box(ids: ids)
        return {
            guard !box.ids.isEmpty else {
                Issue.record("ID generator exhausted")
                return UUID()
            }
            return box.ids.removeFirst()
        }
    }

    private func decimal(_ string: String) -> Decimal {
        Decimal(string: string) ?? 0
    }
}
