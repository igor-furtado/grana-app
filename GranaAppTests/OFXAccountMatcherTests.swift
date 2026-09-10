import Foundation
import Testing
@testable import GranaApp

@Suite("OFXAccountMatcher")
struct OFXAccountMatcherTests {
    @Test("Código bancário OFX com zero à esquerda resolve instituição")
    func bankCodeWithLeadingZeroMatchesInstitution() {
        let institution = makeInstitution(code: "341")

        let match = [institution].institution(code: "0341", supporting: .ofx)

        #expect(match?.id == institution.id)
    }

    @Test("ACCTID do Itaú com agência embutida detecta conta cadastrada")
    func itauAccountIdWithEmbeddedBranchMatchesStoredAccount() {
        let institution = makeInstitution(code: "341")
        let accountId = UUID()
        let account = Account(
            id: accountId,
            type: .checking,
            initialBalance: 0,
            archived: false,
            institutionId: institution.id,
            createdAt: Date(),
            updatedAt: Date()
        )
        let details = BankAccountDetails(
            accountId: accountId,
            branchId: "4525",
            accountNumber: "0057763-3",
            bankName: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let key = OFXAccountKey(
            bankId: "0341",
            branchId: nil,
            accountId: "4525577633"
        )

        let match = OFXAccountMatcher.matchedAccountId(
            for: key,
            accounts: [account],
            institutions: [institution],
            bankDetails: [details]
        )

        #expect(match == accountId)
    }

    @Test("OFX sem agência não detecta conta quando agência cadastrada não está embutida")
    func missingBranchDoesNotMatchStoredAccountWithBranch() {
        let institution = makeInstitution(code: "341")
        let accountId = UUID()
        let account = Account(
            id: accountId,
            type: .checking,
            initialBalance: 0,
            archived: false,
            institutionId: institution.id,
            createdAt: Date(),
            updatedAt: Date()
        )
        let details = BankAccountDetails(
            accountId: accountId,
            branchId: "4525",
            accountNumber: "0057763-3",
            bankName: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let key = OFXAccountKey(
            bankId: "0341",
            branchId: nil,
            accountId: "0057763-3"
        )

        let match = OFXAccountMatcher.matchedAccountId(
            for: key,
            accounts: [account],
            institutions: [institution],
            bankDetails: [details]
        )

        #expect(match == nil)
    }

    @Test("ACCTID com agência e zeros preservados detecta conta cadastrada")
    func embeddedBranchWithStoredLeadingZerosMatchesAccount() {
        let institution = makeInstitution(code: "341")
        let accountId = UUID()
        let account = Account(
            id: accountId,
            type: .checking,
            initialBalance: 0,
            archived: false,
            institutionId: institution.id,
            createdAt: Date(),
            updatedAt: Date()
        )
        let details = BankAccountDetails(
            accountId: accountId,
            branchId: "4525",
            accountNumber: "0057763-3",
            bankName: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let key = OFXAccountKey(
            bankId: "0341",
            branchId: nil,
            accountId: "452500577633"
        )

        let match = OFXAccountMatcher.matchedAccountId(
            for: key,
            accounts: [account],
            institutions: [institution],
            bankDetails: [details]
        )

        #expect(match == accountId)
    }
}

private func makeInstitution(code: String) -> Institution {
    Institution(
        id: UUID(),
        code: code,
        name: "Itaú",
        kind: .itau,
        capabilities: InstitutionCapabilities(
            supportedAccountTypes: [.checking],
            supportedImportFormats: [.ofx]
        ),
        createdAt: Date(),
        updatedAt: Date()
    )
}
