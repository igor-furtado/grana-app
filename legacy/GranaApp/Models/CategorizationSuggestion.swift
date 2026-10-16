import Foundation

/// Sugestão de classificação para uma transação específica, materializada em
/// memória durante o wizard de importação.
///
/// `source` distingue:
/// - `.fallback` — transação entra em "Não Classificado" para revisão manual.
/// - `.granaAI` — sugestão veio do classificador local validada contra a taxonomia.
struct CategorizationSuggestion: Identifiable, Hashable {
    enum Source: String, Hashable {
        case fallback
        case granaAI
    }

    let id: UUID
    let transactionId: UUID
    /// Hash SHA256 da descrição normalizada usado para propagar correções
    /// entre sugestões com mesma descrição.
    let descriptionHash: String
    /// Descrição normalizada localmente.
    let normalizedDescription: String

    var categoryId: UUID
    var subcategoryId: UUID?
    let source: Source

    let originalCategoryId: UUID?
    let originalSubcategoryId: UUID?
    let originalCategorySlug: String?
    let originalSubcategoryName: String?

    /// Snapshot do draft pra renderizar a row sem depender de outro estado do wizard.
    var transactionDescription: String
    var transactionAmount: Decimal // magnitude (`abs`) — UI renderiza assim
    var transactionOccurredAt: Date
    var transactionAccountId: UUID
    var transactionNotes: String?
    var transactionDestinationAccountId: UUID?
    /// Marca de revisão. Quando o usuário aceita explicitamente (botão de
    /// confirm), vira true. Correção também marca como reviewed automaticamente.
    var isReviewed: Bool
}
