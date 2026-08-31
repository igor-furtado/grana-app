import Foundation

/// Versão pré-banco de uma `Transaction` — usada entre o preview e o commit
/// final do import, enquanto o usuário revisa a classificação.
///
/// **Por que existe:** a importação revisa antes da inserção no banco. O draft
/// preserva o `signedAmount` original (com sinal vindo do CSV/OFX), que a
/// `Transaction` perde no `abs()` exigido pela convenção do app (ver
/// invariantes em `AGENTS.md`).
///
/// **`id` já fixado**: gerado quando o draft é criado, propagado pra
/// `Transaction.id` no commit. Permite usar o mesmo UUID em
/// `CategorizationSuggestion.transactionId` durante a revisão.
struct TransactionDraft: Identifiable, Hashable {
    let id: UUID
    let accountId: UUID
    let importBatchId: UUID
    /// Valor com sinal original (negativo = saída, positivo = entrada). No
    /// commit final é `abs()`-eado.
    let signedAmount: Decimal
    let isSignReliable: Bool
    let occurredAt: Date
    let originOccurredAt: Date
    let purchaseType: TransactionPurchaseType?
    let installmentIndex: Int?
    let installmentCount: Int?
    let description: String
    let notes: String?
    /// FITID do OFX, quando existir. CSV/XLSX = nil.
    let externalId: String?
    let destinationAccountId: UUID?
    /// Categoria fornecida pelo sistema de origem (ex: coluna "Categoria"
    /// do CSV do Inter: SUPERMERCADO, TRANSPORTE, BARES…). **Não é nossa
    /// taxonomia**. `nil` quando a fonte não fornece.
    let sourceCategoryHint: String?
    init(
        id: UUID,
        accountId: UUID,
        importBatchId: UUID,
        signedAmount: Decimal,
        isSignReliable: Bool = true,
        occurredAt: Date,
        originOccurredAt: Date? = nil,
        purchaseType: TransactionPurchaseType? = nil,
        installmentIndex: Int? = nil,
        installmentCount: Int? = nil,
        description: String,
        notes: String?,
        externalId: String?,
        destinationAccountId: UUID? = nil,
        sourceCategoryHint: String? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.importBatchId = importBatchId
        self.signedAmount = signedAmount
        self.isSignReliable = isSignReliable
        self.occurredAt = occurredAt
        self.originOccurredAt = originOccurredAt ?? occurredAt
        self.purchaseType = purchaseType
        self.installmentIndex = installmentIndex
        self.installmentCount = installmentCount
        self.description = description
        self.notes = notes
        self.externalId = externalId
        self.destinationAccountId = destinationAccountId
        self.sourceCategoryHint = sourceCategoryHint
    }
}
