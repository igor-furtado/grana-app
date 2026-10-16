import CryptoKit
import Foundation
import Testing
@testable import GranaApp

@Suite("TransactionDedupKey")
struct TransactionDedupKeyTests {
    @Test("Assinatura usa formato versionado e valores literais")
    func usesVersionedCanonicalPayloadWithLiteralValues() throws {
        let accountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let originOccurredAt = Date(timeIntervalSince1970: 1_787_000_000)

        let key = TransactionDedupKey.make(
            accountId: accountId,
            amount: Decimal(string: "123.45") ?? 0,
            description: "PIX JOAO",
            purchaseType: .installment,
            installmentIndex: 2,
            installmentCount: 3,
            originOccurredAt: originOccurredAt
        )

        #expect(key == expectedSHA256(fields: [
            "\"v\":1",
            "\"account_id\":\"00000000-0000-0000-0000-000000000101\"",
            "\"amount_cents\":12345",
            "\"description\":\"PIX JOAO\"",
            "\"purchase_type\":\"installment\"",
            "\"installment_index\":2",
            "\"installment_count\":3",
            "\"origin_occurred_at\":\"2026-08-19T18:13:20.000Z\"",
        ]))
    }

    @Test("Descrição não é normalizada")
    func descriptionIsNotNormalized() throws {
        let accountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let originOccurredAt = Date(timeIntervalSince1970: 1_787_000_000)

        let uppercase = TransactionDedupKey.make(
            accountId: accountId,
            amount: 10,
            description: "PIX JOAO",
            purchaseType: nil,
            installmentIndex: nil,
            installmentCount: nil,
            originOccurredAt: originOccurredAt
        )
        let lowercase = TransactionDedupKey.make(
            accountId: accountId,
            amount: 10,
            description: "pix joao",
            purchaseType: nil,
            installmentIndex: nil,
            installmentCount: nil,
            originOccurredAt: originOccurredAt
        )

        #expect(uppercase != lowercase)
    }

    @Test("Descrição preserva espaços e quebras de linha")
    func descriptionEscapesWhitespaceWithoutNormalizing() throws {
        let accountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let originOccurredAt = Date(timeIntervalSince1970: 1_787_000_000)

        let key = TransactionDedupKey.make(
            accountId: accountId,
            amount: 10,
            description: " PIX  JOAO\nLOJA ",
            purchaseType: nil,
            installmentIndex: nil,
            installmentCount: nil,
            originOccurredAt: originOccurredAt
        )

        #expect(key == expectedSHA256(fields: [
            "\"v\":1",
            "\"account_id\":\"00000000-0000-0000-0000-000000000101\"",
            "\"amount_cents\":1000",
            "\"description\":\" PIX  JOAO\\nLOJA \"",
            "\"purchase_type\":null",
            "\"installment_index\":null",
            "\"installment_count\":null",
            "\"origin_occurred_at\":\"2026-08-19T18:13:20.000Z\"",
        ]))
    }

    @Test("Data de competência e notas não participam da assinatura")
    func occurredAtAndNotesDoNotParticipate() throws {
        let accountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let first = TransactionDedupKey.make(
            accountId: accountId,
            amount: 10,
            occurredAt: Date(timeIntervalSince1970: 1_787_086_400),
            originOccurredAt: Date(timeIntervalSince1970: 1_787_000_000),
            description: "Compra",
            notes: nil,
            purchaseType: nil,
            installmentIndex: nil,
            installmentCount: nil
        )
        let second = TransactionDedupKey.make(
            accountId: accountId,
            amount: 10,
            occurredAt: Date(timeIntervalSince1970: 1_787_172_800),
            originOccurredAt: Date(timeIntervalSince1970: 1_787_000_000),
            description: "Compra",
            notes: "Organização pessoal",
            purchaseType: nil,
            installmentIndex: nil,
            installmentCount: nil
        )

        #expect(first == second)
    }

    @Test("Nulo é diferente de zero")
    func nullIsDifferentFromZero() throws {
        let accountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let originOccurredAt = Date(timeIntervalSince1970: 1_787_000_000)

        let nilInstallment = TransactionDedupKey.make(
            accountId: accountId,
            amount: 10,
            description: "Compra",
            purchaseType: nil,
            installmentIndex: nil,
            installmentCount: nil,
            originOccurredAt: originOccurredAt
        )
        let zeroInstallment = TransactionDedupKey.make(
            accountId: accountId,
            amount: 10,
            description: "Compra",
            purchaseType: nil,
            installmentIndex: 0,
            installmentCount: 0,
            originOccurredAt: originOccurredAt
        )

        #expect(nilInstallment != zeroInstallment)
    }
}

private func expectedSHA256(_ payload: String) -> String {
    let digest = SHA256.hash(data: Data(payload.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

private func expectedSHA256(fields: [String]) -> String {
    expectedSHA256("{\(fields.joined(separator: ","))}")
}
