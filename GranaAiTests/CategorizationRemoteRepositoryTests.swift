import Foundation
import Testing
@testable import GranaAi

@Suite("CategorizationRemoteRepository")
struct CategorizationRemoteRepositoryTests {
    @Test("Mapeia contrato remoto de sugestões preservando fallback e campos pseudonimizados")
    func mapsSuggestionDTOsAndFallback() async throws {
        let repository = CategorizationRemoteRepository(
            remoteStore: FakeCategorizationRemoteStore(
                data: Data(
                    """
                    {
                      "results": [
                        {
                          "index": 0,
                          "description_hash": "hash-1",
                          "normalized_description": "mercado",
                          "category_slug": "nao-classificado",
                          "subcategory_name": null,
                          "confidence": 0,
                          "source": "fallback"
                        }
                      ],
                      "metadata": {
                        "provider": "openai",
                        "model": "gpt-5.4-mini",
                        "from_cache": 0,
                        "from_ai": 0,
                        "fallback_count": 1
                      }
                    }
                    """.utf8
                )
            )
        )

        let result = try await repository.classify(
            request: CategorizationPrompt.buildRequest(
                items: [],
                categories: [],
                ownAccounts: [],
                taxonomyVersion: 1
            )
        )

        #expect(result.suggestions.count == 1)
        #expect(result.suggestions[0].descriptionHash == "hash-1")
        #expect(result.suggestions[0].normalizedDescription == "mercado")
        #expect(result.suggestions[0].categorySlug == "nao-classificado")
        #expect(result.suggestions[0].source == .fallback)
        #expect(result.metadata?.model == "gpt-5.4-mini")
    }

    @Test("Mapeia código estável de autenticação inválida")
    func mapsInvalidUserJWTCode() async {
        let repository = CategorizationRemoteRepository(
            remoteStore: FakeCategorizationRemoteStore(
                error: AIError.httpStatus(401, body: #"{"code":"invalid_user_jwt"}"#)
            )
        )

        await #expect(throws: CategorizationRemoteRepositoryError.authenticationRequired) {
            _ = try await repository.classify(
                request: CategorizationPrompt.buildRequest(
                    items: [],
                    categories: [],
                    ownAccounts: [],
                    taxonomyVersion: 1
                )
            )
        }
    }

    @Test("Mapeia falta de cota da OpenAI para erro específico")
    func mapsOpenAIInsufficientQuota() async {
        let repository = CategorizationRemoteRepository(
            remoteStore: FakeCategorizationRemoteStore(
                error: AIError.httpStatus(
                    429,
                    body: #"{"code":"openai_insufficient_quota","provider_status":429}"#
                )
            )
        )

        await #expect(throws: CategorizationRemoteRepositoryError.quotaExceeded) {
            _ = try await repository.classify(
                request: CategorizationPrompt.buildRequest(
                    items: [],
                    categories: [],
                    ownAccounts: [],
                    taxonomyVersion: 1
                )
            )
        }
    }

    @Test("Mapeia limite de taxa da OpenAI preservando retry-after")
    func mapsOpenAIRateLimit() async {
        let repository = CategorizationRemoteRepository(
            remoteStore: FakeCategorizationRemoteStore(
                error: AIError.httpStatus(
                    429,
                    body: #"{"code":"openai_rate_limit_exceeded","provider_status":429,"retry_after_seconds":17}"#
                )
            )
        )

        await #expect(throws: CategorizationRemoteRepositoryError.rateLimited(retryAfterSeconds: 17)) {
            _ = try await repository.classify(
                request: CategorizationPrompt.buildRequest(
                    items: [],
                    categories: [],
                    ownAccounts: [],
                    taxonomyVersion: 1
                )
            )
        }
    }
}

private actor FakeCategorizationRemoteStore: CategorizationRemoteStore {
    let data: Data
    let error: (any Error)?

    init(data: Data = Data(#"{"results":[]}"#.utf8), error: (any Error)? = nil) {
        self.data = data
        self.error = error
    }

    func classify(request _: CategorizationPrompt.APIRequest) async throws -> Data {
        if let error {
            throw error
        }
        return data
    }
}
