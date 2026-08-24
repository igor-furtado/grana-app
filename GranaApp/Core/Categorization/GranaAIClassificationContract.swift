import Foundation

nonisolated enum GranaAIContract {
    static let version = "classification.v1"
}

nonisolated struct GranaAIClassificationRequest: Codable, Equatable {
    let version: String
    let transactions: [Transaction]
    let taxonomy: Taxonomy
    let context: Context

    struct Transaction: Codable, Equatable {
        let id: String
        let description: String
        let amountInMinorUnits: Int64?
        let currencyCode: String?
    }

    struct Taxonomy: Codable, Equatable {
        let categories: [Category]
    }

    struct Category: Codable, Equatable {
        let id: String
        let name: String
        let subcategories: [Subcategory]
    }

    struct Subcategory: Codable, Equatable {
        let id: String
        let name: String
    }

    struct Context: Codable, Equatable {
        let locale: String?
    }
}

nonisolated struct GranaAIClassificationResponse: Codable, Equatable {
    let version: String
    let results: [Result]

    struct Result: Codable, Equatable {
        let transactionId: String
        let outcome: Outcome

        enum CodingKeys: String, CodingKey {
            case transactionId
            case outcome
            case categoryId
            case subcategoryId
            case fallbackReason
        }

        init(transactionId: String, outcome: Outcome) {
            self.transactionId = transactionId
            self.outcome = outcome
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.transactionId = try container.decode(String.self, forKey: .transactionId)
            let outcomeValue = try container.decode(String.self, forKey: .outcome)

            switch outcomeValue {
            case "classified":
                self.outcome = try .classified(
                    categoryId: container.decode(String.self, forKey: .categoryId),
                    subcategoryId: container.decodeIfPresent(String.self, forKey: .subcategoryId)
                )
            case "fallback":
                self.outcome = try .fallback(
                    reason: container.decodeIfPresent(String.self, forKey: .fallbackReason)
                )
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .outcome,
                    in: container,
                    debugDescription: "Unsupported GranaAI outcome: \(outcomeValue)"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(transactionId, forKey: .transactionId)

            switch outcome {
            case let .classified(categoryId, subcategoryId):
                try container.encode("classified", forKey: .outcome)
                try container.encode(categoryId, forKey: .categoryId)
                try container.encodeIfPresent(subcategoryId, forKey: .subcategoryId)
            case let .fallback(reason):
                try container.encode("fallback", forKey: .outcome)
                try container.encodeIfPresent(reason, forKey: .fallbackReason)
            }
        }
    }

    enum Outcome: Equatable {
        case classified(categoryId: String, subcategoryId: String?)
        case fallback(reason: String?)
    }
}

nonisolated struct GranaAIClassificationLearningRequest: Codable, Equatable {
    let version: String
    let taxonomy: GranaAIClassificationRequest.Taxonomy
    let confirmedClassifications: [ConfirmedClassification]

    struct ConfirmedClassification: Codable, Equatable {
        let description: String
        let categoryId: String
        let subcategoryId: String?
    }
}

nonisolated struct GranaAIContractErrorResponse: Codable, Equatable, Error {
    let code: String
    let message: String
}

nonisolated protocol GranaAIClassificationClientProtocol: Sendable {
    func classify(_ request: GranaAIClassificationRequest) async throws -> GranaAIClassificationResponse
    func learn(_ request: GranaAIClassificationLearningRequest) async throws
}
