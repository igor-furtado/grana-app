import Foundation
@testable import GranaApp

func makeCheckingInstitution(
    id: UUID = UUID(),
    name: String = "Banco Inter",
    code: String = "077",
    kind: InstitutionKind = .inter
) -> Institution {
    Institution(
        id: id,
        code: code,
        name: name,
        kind: kind,
        capabilities: InstitutionCapabilities(
            supportedAccountTypes: [.checking],
            supportedImportFormats: [.ofx]
        ),
        createdAt: Date(),
        updatedAt: Date()
    )
}

func makeCheckingAccountItem(
    id: UUID = UUID(),
    institution: Institution? = nil,
    archived: Bool = false,
    balance: Decimal = 0,
    accountNumber: String = "1234"
) -> AccountListItem {
    let account = Account(
        id: id,
        type: .checking,
        initialBalance: balance,
        archived: archived,
        institutionId: institution?.id,
        currency: "BRL",
        createdAt: Date(),
        updatedAt: Date()
    )

    return AccountListItem(
        account: account,
        institution: institution,
        bankDetails: BankAccountDetails(
            accountId: id,
            branchId: "0001",
            accountNumber: accountNumber,
            createdAt: account.createdAt,
            updatedAt: account.updatedAt
        ),
        currentBalance: balance
    )
}
