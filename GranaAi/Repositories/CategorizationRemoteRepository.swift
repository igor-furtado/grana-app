import Foundation

protocol CategorizationRemoteRepositoryProtocol: Sendable {
    func classify(
        request: CategorizationPrompt.APIRequest
    ) async throws -> CategorizationRemoteResult
}

nonisolated enum CategorizationRemoteRepositoryError: UserFacingError, Equatable {
    case authenticationRequired
    case invalidConfiguration
    case unsupportedProvider
    case invalidRequest
    case quotaExceeded
    case rateLimited(retryAfterSeconds: Int?)
    case unavailable
    case unexpectedResponse

    var errorTitle: String {
        "Falha ao categorizar"
    }

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "É preciso entrar com sua conta para usar a categorização assistida."
        case .invalidConfiguration:
            return "A configuração remota da categorização assistida está incompleta."
        case .unsupportedProvider:
            return "O provider remoto configurado para categorização não é suportado."
        case .invalidRequest:
            return "O payload enviado para categorização ficou inválido."
        case .quotaExceeded:
            return "A chave remota da OpenAI ficou sem cota ou sem billing ativo para a categorização assistida."
        case let .rateLimited(retryAfterSeconds):
            if let retryAfterSeconds, retryAfterSeconds > 0 {
                return "A OpenAI atingiu o limite de taxa agora. Tente novamente em cerca de \(retryAfterSeconds) segundos."
            }
            return "A OpenAI atingiu o limite de taxa agora. Tente novamente em instantes."
        case .unavailable:
            return "Não foi possível falar com o serviço de categorização."
        case .unexpectedResponse:
            return "A resposta do backend para categorização veio inválida."
        }
    }

    static func from(code: String, retryAfterSeconds: Int? = nil) -> CategorizationRemoteRepositoryError {
        switch code {
        case "missing_authorization", "invalid_user_jwt":
            return .authenticationRequired
        case "invalid_request":
            return .invalidRequest
        case "missing_runtime_config":
            return .invalidConfiguration
        case "openai_insufficient_quota":
            return .quotaExceeded
        case "openai_rate_limit_exceeded":
            return .rateLimited(retryAfterSeconds: retryAfterSeconds)
        default:
            if code.hasPrefix("missing_env:") {
                return .invalidConfiguration
            }
            if code.hasPrefix("unsupported_provider:") {
                return .unsupportedProvider
            }
            return .unexpectedResponse
        }
    }
}

nonisolated enum CategorizationRemoteSuggestionSource: String, Decodable, Hashable, Sendable {
    case cache
    case ai
    case fallback
}

nonisolated struct CategorizationRemoteSuggestion: Hashable, Sendable {
    let index: Int
    let descriptionHash: String
    let normalizedDescription: String
    let categorySlug: String
    let subcategoryName: String?
    let confidence: Double
    let source: CategorizationRemoteSuggestionSource
}

nonisolated struct CategorizationRemoteResult: Hashable, Sendable {
    let suggestions: [CategorizationRemoteSuggestion]
    let metadata: CategorizationPrompt.APIMetadata?
}

protocol CategorizationRemoteStore: Sendable {
    func classify(request: CategorizationPrompt.APIRequest) async throws -> Data
}

actor SupabaseCategorizationRemoteStore: CategorizationRemoteStore {
    private let client: CategorizationAPIClient

    init(client: CategorizationAPIClient) {
        self.client = client
    }

    func classify(request: CategorizationPrompt.APIRequest) async throws -> Data {
        try await client.categorize(request)
    }
}

final class CategorizationRemoteRepository: CategorizationRemoteRepositoryProtocol, Sendable {
    private let remoteStore: any CategorizationRemoteStore

    init(remoteStore: any CategorizationRemoteStore) {
        self.remoteStore = remoteStore
    }

    func classify(
        request: CategorizationPrompt.APIRequest
    ) async throws -> CategorizationRemoteResult {
        do {
            let envelope = try CategorizationPrompt.parseResponse(
                from: try await remoteStore.classify(request: request)
            )
            return CategorizationRemoteResult(
                suggestions: envelope.results.map { result in
                    CategorizationRemoteSuggestion(
                        index: result.index,
                        descriptionHash: result.descriptionHash,
                        normalizedDescription: result.normalizedDescription,
                        categorySlug: result.categorySlug,
                        subcategoryName: result.subcategoryName,
                        confidence: result.confidence,
                        source: result.source
                    )
                },
                metadata: envelope.metadata
            )
        } catch let error as CategorizationRemoteRepositoryError {
            throw error
        } catch let error as AIError {
            throw Self.map(error: error)
        }
    }

    private static func map(error: AIError) -> CategorizationRemoteRepositoryError {
        switch error {
        case .authenticationRequired:
            return .authenticationRequired
        case .requestFailed, .cancelled:
            return .unavailable
        case .invalidConfiguration:
            return .invalidConfiguration
        case let .httpStatus(_, body):
            guard let payload = backendError(from: body) else {
                return .unexpectedResponse
            }
            guard let code = payload.code ?? payload.error else {
                return .unexpectedResponse
            }
            let mapped = CategorizationRemoteRepositoryError.from(
                code: code,
                retryAfterSeconds: payload.retryAfterSeconds
            )
            return mapped == .unexpectedResponse ? .unavailable : mapped
        case .invalidResponse, .responseParse, .decoding, .unknownCategorySlug:
            return .unexpectedResponse
        }
    }

    private static func backendError(from body: String?) -> CategorizationErrorBody? {
        guard let body, !body.isEmpty else { return nil }
        guard let data = body.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CategorizationErrorBody.self, from: data)
    }
}

struct StaticCategorizationRemoteRepository: CategorizationRemoteRepositoryProtocol {
    var result: CategorizationRemoteResult = .init(
        suggestions: [],
        metadata: nil
    )

    func classify(
        request _: CategorizationPrompt.APIRequest
    ) async throws -> CategorizationRemoteResult {
        result
    }
}

struct AuthRequiredCategorizationRemoteRepo: CategorizationRemoteRepositoryProtocol {
    func classify(
        request _: CategorizationPrompt.APIRequest
    ) async throws -> CategorizationRemoteResult {
        throw CategorizationRemoteRepositoryError.authenticationRequired
    }
}

private struct CategorizationErrorBody: Decodable {
    let code: String?
    let error: String?
    let message: String?
    let retryAfterSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case code
        case error
        case message
        case retryAfterSeconds = "retry_after_seconds"
    }
}
