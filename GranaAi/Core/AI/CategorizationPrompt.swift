import Foundation
import OSLog

/// Monta o payload do backend online pro pipeline de categorização.
///
/// **Estratégia:**
/// - O app continua sendo a fonte da taxonomia e envia ao backend as
///   categorias e subcategorias válidas do batch.
/// - O backend recebe transações e o recorte taxonômico; memória pessoal e
///   configuração operacional são resolvidas server-side.
/// - A resposta continua sendo JSON estruturado no mesmo contrato lógico.
///
/// **`nonisolated`:** chamado do service rodando off-main.
nonisolated enum CategorizationPrompt {
    /// Item de input pra IA — descrição + valor + data + conta por linha.
    struct Item: Encodable {
        let index: Int
        let description: String
        /// Valor com sinal pra IA inferir kind do contexto (CSV/XLSX trazem
        /// sinal antes de normalizar; isso ajuda o modelo a decidir income vs
        /// expense quando a descrição é ambígua, ex: "PIX RECEBIDO" vs "PIX ENVIADO").
        let sign: String // "income" | "expense" | "unknown"
        /// Conta onde a transação está sendo registrada (nome + tipo). Permite
        /// à IA entender o contexto: ex. uma compra dentro de uma conta-cartão
        /// nunca é transferência — é despesa direta no cartão.
        let accountContext: String
        /// Categoria sugerida pelo sistema de origem (ex: coluna "Categoria"
        /// do CSV do Inter: SUPERMERCADO, BARES, TRANSPORTE). **Não é nossa
        /// taxonomia**, mas reduz incerteza em descrições genéricas. `nil`
        /// quando a fonte não fornece.
        let sourceHint: String?

        enum CodingKeys: String, CodingKey {
            case index
            case description
            case sign
            case accountContext = "account_context"
            case sourceHint = "source_hint"
        }
    }

    /// Categoria raiz exposta pro modelo (resolução slug→UUID acontece no service).
    struct CategoryOption: Encodable {
        struct SubcategoryOption: Encodable {
            let id: UUID
            let name: String
        }

        let id: UUID
        let slug: String
        let name: String
        let kind: String // "expense" | "income" | "transfer"
        let subcategories: [SubcategoryOption]
    }

    /// Conta do usuário exposta pro modelo. Serve pra decidir se uma
    /// transação é transferência entre contas próprias (raiz `transferencias`)
    /// ou movimento com terceiro (categoriza pela natureza).
    struct OwnAccountInfo: Encodable {
        let name: String
        let typeDisplay: String // "Conta Corrente", "Poupança", etc
        let institutionName: String?

        enum CodingKeys: String, CodingKey {
            case name
            case typeDisplay = "type_display"
            case institutionName = "institution_name"
        }
    }

    struct APIRequest: Encodable {
        let taxonomyVersion: Int
        let items: [Item]
        let categories: [CategoryOption]
        let ownAccounts: [OwnAccountInfo]

        enum CodingKeys: String, CodingKey {
            case taxonomyVersion = "taxonomy_version"
            case items
            case categories
            case ownAccounts = "own_accounts"
        }
    }

    struct APIMetadata: Decodable, Hashable {
        let provider: String?
        let model: String?
        let fromCache: Int?
        let fromAI: Int?
        let fallbackCount: Int?

        enum CodingKeys: String, CodingKey {
            case provider
            case model
            case fromCache = "from_cache"
            case fromAI = "from_ai"
            case fallbackCount = "fallback_count"
        }
    }

    /// Monta o payload completo enviado ao backend.
    static func buildRequest(
        items: [Item],
        categories: [CategoryOption],
        ownAccounts: [OwnAccountInfo],
        taxonomyVersion: Int
    ) -> APIRequest {
        APIRequest(
            taxonomyVersion: taxonomyVersion,
            items: items,
            categories: categories,
            ownAccounts: ownAccounts
        )
    }

    // MARK: - Parsing da resposta

    /// Resultado decodificado do JSON estruturado.
    struct ClassificationResult: Hashable {
        let index: Int
        let categorySlug: String
        let subcategoryName: String?
        let confidence: Double
    }

    /// Wrapper externo devolvido pelo backend.
    private struct StructuredResponse: Decodable {
        let results: [ResultItem]
        let metadata: APIMetadata?

        struct ResultItem: Decodable {
            let index: Int
            let categorySlug: String
            let subcategoryName: String?
            let confidence: Double?

            enum CodingKeys: String, CodingKey {
                case index
                case categorySlug = "category_slug"
                case subcategoryName = "subcategory_name"
                case confidence
            }
        }
    }

    /// Decodifica a resposta JSON estruturada devolvida pelo backend.
    static func parseResults(from data: Data) throws -> [ClassificationResult] {
        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode(StructuredResponse.self, from: data)
            return decoded.results.map(Self.normalize)
        } catch {
            let preview = String(data: data, encoding: .utf8)?.prefix(500) ?? "<não-UTF8>"
            log.ai
                .error(
                    "CategorizationPrompt: resposta não-JSON do backend — preview: \(String(preview), privacy: .public)"
                )
            throw AIError.decoding(error)
        }
    }

    private static func normalize(_ item: StructuredResponse.ResultItem) -> ClassificationResult {
        ClassificationResult(
            index: item.index,
            categorySlug: item.categorySlug,
            subcategoryName: item.subcategoryName.flatMap { $0.isEmpty ? nil : $0 },
            confidence: item.confidence.map { max(0.0, min(1.0, $0)) } ?? 0.0
        )
    }
}
