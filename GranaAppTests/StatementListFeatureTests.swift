import Foundation
import Testing
@testable import GranaApp

@Suite("StatementListFeature")
struct StatementListFeatureTests {
    @Test("Tabela de lançamentos deriva tipo, categoria exibida e valor localmente")
    func statementListBuildsTableRows() throws {
        let rootCategoryId = UUID()
        let subcategoryId = UUID()
        let occurredAt = Date(timeIntervalSince1970: 1_727_395_200)
        let row = StatementTransactionRow(
            transaction: Transaction(
                id: UUID(),
                accountId: UUID(),
                categoryId: rootCategoryId,
                subcategoryId: subcategoryId,
                amount: 27.98,
                occurredAt: occurredAt,
                description: "ifood *IFD*Rosa Chur",
                notes: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            category: Category(
                id: rootCategoryId,
                parentId: nil,
                name: "Alimentação",
                kind: .expense,
                slug: "alimentacao",
                createdAt: Date()
            ),
            subcategory: Category(
                id: subcategoryId,
                parentId: rootCategoryId,
                name: "Delivery",
                kind: .expense,
                slug: nil,
                createdAt: Date()
            )
        )

        let state = StatementListFeature.State(statementId: UUID(), rows: [row])
        let tableRow = try #require(state.tableRows.first)

        #expect(tableRow.occurredAt == occurredAt)
        #expect(tableRow.purchaseDisplayName == "À vista")
        #expect(tableRow.categoryName == "Alimentação")
        #expect(tableRow.categoryDisplayName == "Delivery")
        #expect(tableRow.categorySortLabel == "Delivery")
        #expect(tableRow.categoryIcon == .food)
        #expect(tableRow.subcategoryName == "Delivery")
        #expect(tableRow.description == "ifood *IFD*Rosa Chur")
        #expect(tableRow.amount == 27.98)
    }
}
