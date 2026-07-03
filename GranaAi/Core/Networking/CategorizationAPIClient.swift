import Foundation

/// Cliente HTTP da categorização assistida online.
///
/// O app fala diretamente com a Edge Function pública do Supabase. A função
/// resolve provider/modelo ativos, aplica pseudonimização e chama o provedor
/// externo. O app continua dono apenas do batch e do recorte de taxonomia.
final class CategorizationAPIClient: Sendable {
    typealias Transport = @Sendable (URLRequest, URLSession) async throws -> (Data, URLResponse)

    private let urlSession: URLSession
    private let requestTimeout: TimeInterval
    private let authClient: (any AuthClientProtocol)?
    private let endpointURLOverride: URL?
    private let transport: Transport

    init(
        urlSession: URLSession = .shared,
        requestTimeout: TimeInterval = 900,
        authClient: (any AuthClientProtocol)? = nil,
        endpointURL: URL? = nil,
        transport: @escaping Transport = { request, session in
            try await session.data(for: request)
        }
    ) {
        self.urlSession = urlSession
        self.requestTimeout = requestTimeout
        self.authClient = authClient
        self.endpointURLOverride = endpointURL
        self.transport = transport
    }

    func categorize(
        _ requestBody: CategorizationPrompt.APIRequest
    ) async throws -> Data {
        guard let endpoint = endpointURL() else {
            throw AIError.invalidConfiguration("Config.supabaseURL")
        }
        guard let session = try await authClient?.validSession() else {
            throw AIError.authenticationRequired
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.categorization.encode(requestBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await transport(request, urlSession)
        } catch is CancellationError {
            throw AIError.cancelled
        } catch {
            throw AIError.requestFailed(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIError.invalidResponse("Resposta sem HTTPURLResponse")
        }

        guard 200 ..< 300 ~= http.statusCode else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AIError.httpStatus(http.statusCode, body: body)
        }

        return data
    }

    private func endpointURL() -> URL? {
        if let endpointURLOverride {
            return endpointURLOverride
        }
        guard let baseURL = URL(string: Config.supabaseURL) else { return nil }
        return baseURL
            .appendingPathComponent("functions", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("categorize-import", isDirectory: false)
    }
}

private extension JSONEncoder {
    static let categorization: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}
