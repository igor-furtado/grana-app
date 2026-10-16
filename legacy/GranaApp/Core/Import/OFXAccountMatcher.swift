import Foundation

enum OFXAccountMatcher {
    static func institution(
        for bankId: String,
        in institutions: [Institution],
        supporting importFormat: InstitutionImportFormat? = nil
    ) -> Institution? {
        institutions.first { institution in
            guard InstitutionCode.matches(institution.code, bankId) else { return false }
            guard let importFormat else { return true }
            return institution.capabilities.supports(importFormat)
        }
    }

    static func matchedAccountId(
        for accountKey: OFXAccountKey,
        accounts: [Account],
        institutions: [Institution],
        bankDetails: [BankAccountDetails]
    ) -> UUID? {
        guard let institution = institution(for: accountKey.bankId, in: institutions, supporting: .ofx) else {
            return nil
        }

        return accounts.first { account in
            guard account.institutionId == institution.id,
                  let details = bankDetails.first(where: { $0.accountId == account.id })
            else { return false }

            return accountNumbersMatch(
                storedBranch: details.branchId,
                storedAccount: details.accountNumber,
                ofxBranch: accountKey.branchId,
                ofxAccount: accountKey.accountId
            )
        }?.id
    }

    private static func accountNumbersMatch(
        storedBranch: String?,
        storedAccount: String,
        ofxBranch: String?,
        ofxAccount: String
    ) -> Bool {
        let storedAccountDigits = normalizedAccountDigits(storedAccount)
        let ofxAccountDigits = normalizedAccountDigits(ofxAccount)

        guard !storedAccountDigits.isEmpty, !ofxAccountDigits.isEmpty else {
            return false
        }

        if let ofxBranchDigits = ofxBranch.map(normalizedBranchDigits), !ofxBranchDigits.isEmpty {
            guard normalizedBranchDigits(storedBranch ?? "") == ofxBranchDigits else {
                return false
            }
            return flexibleAccountDigitsMatch(storedAccountDigits, ofxAccountDigits)
        }

        let storedBranchDigits = normalizedBranchDigits(storedBranch ?? "")
        guard !storedBranchDigits.isEmpty else {
            return flexibleAccountDigitsMatch(storedAccountDigits, ofxAccountDigits)
        }
        let storedRawAccountDigits = String(storedAccount.filter(\.isNumber))
        return ofxAccountDigits == storedBranchDigits + storedAccountDigits
            || ofxAccountDigits == trimLeadingZeros(storedBranchDigits + storedRawAccountDigits)
    }

    private static func flexibleAccountDigitsMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || trimLeadingZeros(lhs) == trimLeadingZeros(rhs)
    }

    private static func normalizedBranchDigits(_ raw: String) -> String {
        String(raw.filter(\.isNumber))
    }

    private static func normalizedAccountDigits(_ raw: String) -> String {
        trimLeadingZeros(String(raw.filter(\.isNumber)))
    }

    private static func trimLeadingZeros(_ raw: String) -> String {
        let trimmed = raw.drop { $0 == "0" }
        return trimmed.isEmpty && !raw.isEmpty ? "0" : String(trimmed)
    }
}
