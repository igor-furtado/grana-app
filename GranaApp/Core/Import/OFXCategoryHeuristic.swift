import Foundation

/// Mapeia uma transação OFX para uma das categorias **raiz** do app. É um
/// chute educado pra reduzir o trabalho manual. Princípios:
///
/// 1. **Conservador**: na dúvida, manda pra "Não Classificado" em vez de
///    inventar uma categoria duvidosa.
/// 2. **TRNTYPE primeiro, MEMO depois**: o tipo OFX é a fonte mais
///    estruturada. MEMO/NAME enriquecem a revisão, mas não bastam para
///    inferir transferência entre contas próprias.
/// 3. **Sem tabelas em RAM**: recebemos os IDs das raízes resolvidas pela
///    camada de importação e devolvemos um deles — a função fica pura, fácil de testar.
struct OFXCategoryHeuristic {
    /// IDs das categorias raiz relevantes pra heurística. A camada de importação
    /// resolve esses IDs uma vez e passa pra cada chamada de `categoryId(for:)`.
    struct RootCategoryIDs {
        let unclassified: UUID
        let transfers: UUID?
        let income: UUID?
    }

    let roots: RootCategoryIDs

    func categoryId(for transaction: OFXTransaction) -> UUID {
        switch transaction.trnType.uppercased() {
        case "CREDIT", "DEP", "DIRECTDEP", "INT", "DIV":
            return roots.income ?? roots.unclassified
        default:
            // DEBIT/PAYMENT/CHECK/ATM/POS/FEE/SRVCHG/CASH/DIRECTDEBIT/REPEATPMT/OTHER
            return roots.unclassified
        }
    }
}
