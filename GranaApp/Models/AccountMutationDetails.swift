import Foundation

nonisolated struct BankAccountDetailsInput: Hashable {
    var branchId: String?
    var accountNumber: String
    var bankName: String?
}

nonisolated struct CreditCardDetailsInput: Hashable {
    var cardLastFour: String
    var creditLimit: Decimal?
    var statementClosingDay: Int
    var paymentDueDay: Int
}
