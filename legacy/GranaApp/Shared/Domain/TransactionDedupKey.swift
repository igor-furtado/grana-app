import CryptoKit
import Foundation

enum TransactionDedupKey {
    static func make(
        accountId: UUID,
        amount: Decimal,
        occurredAt _: Date,
        originOccurredAt: Date,
        description: String,
        notes _: String?,
        purchaseType: TransactionPurchaseType?,
        installmentIndex: Int?,
        installmentCount: Int?
    ) -> String {
        make(
            accountId: accountId,
            amount: amount,
            description: description,
            purchaseType: purchaseType,
            installmentIndex: installmentIndex,
            installmentCount: installmentCount,
            originOccurredAt: originOccurredAt
        )
    }

    static func make(
        accountId: UUID,
        amount: Decimal,
        description: String,
        purchaseType: TransactionPurchaseType?,
        installmentIndex: Int?,
        installmentCount: Int?,
        originOccurredAt: Date
    ) -> String {
        let payload = canonicalPayload(
            accountId: accountId,
            amount: amount,
            description: description,
            purchaseType: purchaseType,
            installmentIndex: installmentIndex,
            installmentCount: installmentCount,
            originOccurredAt: originOccurredAt
        )
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func canonicalPayload(
        accountId: UUID,
        amount: Decimal,
        description: String,
        purchaseType: TransactionPurchaseType?,
        installmentIndex: Int?,
        installmentCount: Int?,
        originOccurredAt: Date
    ) -> String {
        let fields = [
            "\"v\":1",
            "\"account_id\":\(jsonString(accountId.uuidString.lowercased()))",
            "\"amount_cents\":\(Converters.decimalToCents(amount))",
            "\"description\":\(jsonString(description))",
            "\"purchase_type\":\(jsonNullableString(purchaseType?.rawValue))",
            "\"installment_index\":\(jsonNullableInt(installmentIndex))",
            "\"installment_count\":\(jsonNullableInt(installmentCount))",
            "\"origin_occurred_at\":\(jsonString(isoString(from: originOccurredAt)))",
        ]
        return "{\(fields.joined(separator: ","))}"
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func jsonNullableInt(_ value: Int?) -> String {
        value.map(String.init) ?? "null"
    }

    private static func jsonNullableString(_ value: String?) -> String {
        value.map(jsonString) ?? "null"
    }

    private static func jsonString(_ value: String) -> String {
        var escaped = "\""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x08:
                escaped += "\\b"
            case 0x09:
                escaped += "\\t"
            case 0x0A:
                escaped += "\\n"
            case 0x0C:
                escaped += "\\f"
            case 0x0D:
                escaped += "\\r"
            case 0x22:
                escaped += "\\\""
            case 0x5C:
                escaped += "\\\\"
            case 0x00 ... 0x1F:
                escaped += String(format: "\\u%04x", scalar.value)
            default:
                escaped.unicodeScalars.append(scalar)
            }
        }
        escaped += "\""
        return escaped
    }
}
