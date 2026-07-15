import Foundation
import Testing
@testable import GranaAi

@Suite("CategorizationAPIClient")
struct CategorizationAPIClientTests {
    @MainActor
    @Test("Anexa JWT da sessão autenticada no header Authorization")
    func attachesBearerTokenFromAuthenticatedSession() async throws {
        let anonKey = Config.supabaseAnonKey
        let session = URLSession(configuration: .ephemeral)
        let recorder = RequestRecorder()
        let client = CategorizationAPIClient(
            urlSession: session,
            requestTimeout: 1,
            authClient: FakeCategorizationAuthClient(validSession: .init(
                userID: UUID(),
                email: "pessoa@exemplo.com",
                accessToken: "jwt-de-teste"
            )),
            endpointURL: URL(string: "https://example.com/functions/v1/categorize-import"),
            transport: recorder.record(_:session:)
        )

        _ = try await client.categorize(CategorizationPrompt.buildRequest(
            items: [],
            categories: [],
            ownAccounts: [],
            taxonomyVersion: 1
        ))

        let request = try #require(await recorder.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-de-teste")
        #expect(request.value(forHTTPHeaderField: "apikey") == anonKey)
    }

    @MainActor
    @Test("Falha cedo quando não existe sessão autenticada")
    func rejectsAnonymousCategorizationRequest() async throws {
        let client = CategorizationAPIClient(
            urlSession: .shared,
            requestTimeout: 1,
            authClient: FakeCategorizationAuthClient(validSession: nil),
            endpointURL: URL(string: "https://example.com/functions/v1/categorize-import"),
            transport: { _, _ in
                Issue.record("não deveria tentar rede sem JWT")
                return (Data(), HTTPURLResponse())
            }
        )

        await #expect(throws: AIError.self) {
            _ = try await client.categorize(CategorizationPrompt.buildRequest(
                items: [],
                categories: [],
                ownAccounts: [],
                taxonomyVersion: 1
            ))
        }
    }
}

private actor RequestRecorder {
    private(set) var lastRequest: URLRequest?

    func record(_ request: URLRequest, session _: URLSession) async throws -> (Data, URLResponse) {
        lastRequest = request
        return (
            Data("{}".utf8),
            HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ) ?? URLResponse()
        )
    }
}

private actor FakeCategorizationAuthClient: AuthClientProtocol {
    private let validSession: AuthSessionContext?

    init(validSession: AuthSessionContext?) {
        self.validSession = validSession
    }

    func validSession() async throws -> AuthSessionContext? {
        validSession
    }

    func storedSession() async -> AuthSessionContext? {
        validSession
    }

    func requestMagicLink(email _: String) async throws {}

    func session(from _: URL) async throws -> AuthSessionContext {
        throw CancellationError()
    }
}
