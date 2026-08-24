import Foundation
import PostgREST

/// Protocolo opcional pra erros que querem controlar o **título** exibido no
/// toast global. Sem implementar, o `NoticeCenter` cai num título genérico
/// derivado do tipo do erro ("ImportError", "AIError", …).
///
/// A *mensagem* sempre vem de `LocalizedError.errorDescription`, então os
/// enums de domínio já existentes (`ImportError`, `AIError`,
/// `CategorizationError`) funcionam sem precisar conformar a este protocolo.
protocol UserFacingError: LocalizedError {
    /// Cabeçalho curto do toast. Padrão: nome legível do caso.
    var errorTitle: String { get }
}

enum AppConfigurationError: UserFacingError, Equatable {
    case placeholderValue(String)
    case invalidURL(String)
    case invalidAPIKey(String)
    case invalidExposedSchema(String)

    var errorTitle: String {
        "Configuração inválida"
    }

    var errorDescription: String? {
        switch self {
        case let .placeholderValue(key):
            return "Preencha \(key) com o valor real antes de usar este recurso."
        case let .invalidURL(key):
            return "A URL informada em \(key) é inválida."
        case let .invalidAPIKey(key):
            return "Atualize \(key) com a publishable key do projeto Supabase atual."
        case let .invalidExposedSchema(schema):
            return "Exponha o schema \(schema) em Data API > Exposed schemas no projeto Supabase."
        }
    }
}

enum AppConfigurationValidator {
    nonisolated static func supabaseURL(_ rawValue: String) throws -> URL {
        try validatedURL(
            rawValue,
            key: "Config.supabaseURL",
            placeholderMarkers: [
                "your_project",
                "your-project",
            ]
        )
    }

    nonisolated static func supabaseAnonKey(_ rawValue: String) throws -> String {
        try validatedValue(
            rawValue,
            key: "Config.supabaseAnonKey",
            placeholderMarkers: [
                "your_anon_key",
                "your-anon-key",
                "your_publishable_key",
                "your-publishable-key",
            ]
        )
    }

    private nonisolated static func validatedURL(
        _ rawValue: String,
        key: String,
        placeholderMarkers: [String]
    ) throws -> URL {
        let trimmed = try validatedValue(
            rawValue,
            key: key,
            placeholderMarkers: placeholderMarkers
        )
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            throw AppConfigurationError.invalidURL(key)
        }
        return url
    }

    private nonisolated static func validatedValue(
        _ rawValue: String,
        key: String,
        placeholderMarkers: [String]
    ) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        if trimmed.isEmpty || placeholderMarkers.contains(where: normalized.contains) {
            throw AppConfigurationError.placeholderValue(key)
        }

        return trimmed
    }
}

/// Tupla `(título, mensagem)` que o `NoticeCenter` consome.
struct AppErrorPresentation: Equatable {
    let title: String
    let message: String

    /// Extrai título + descrição de qualquer `Error`. A heurística cobre os
    /// erros tipados do app (todos `LocalizedError` em PT-BR) e degrada
    /// gracioso pra `NSError`/`Error` cru.
    static func from(_ error: Error, overrideTitle: String? = nil) -> AppErrorPresentation {
        let normalizedError = normalized(error)
        let message: String
        if let localized = normalizedError as? LocalizedError, let desc = localized.errorDescription {
            message = desc
        } else {
            message = (normalizedError as NSError).localizedDescription
        }

        let title: String = {
            if let overrideTitle { return overrideTitle }
            if let userFacing = normalizedError as? UserFacingError { return userFacing.errorTitle }
            return defaultTitle(for: normalizedError)
        }()

        return AppErrorPresentation(title: title, message: message)
    }

    private static func normalized(_ error: Error) -> Error {
        guard let postgrestError = error as? PostgrestError else {
            return error
        }

        if postgrestError.code == "PGRST106",
           let schema = postgrestError.message.split(separator: ":").last?
               .trimmingCharacters(in: .whitespacesAndNewlines),
           !schema.isEmpty
        {
            return AppConfigurationError.invalidExposedSchema(schema)
        }

        return error
    }

    /// Título "amigável" derivado do tipo. Mapeia os enums conhecidos pra
    /// rótulos em PT-BR; tipos desconhecidos viram "Erro inesperado".
    private static func defaultTitle(for error: Error) -> String {
        switch error {
        case is ImportError: return "Erro na importação"
        case is AppConfigurationError: return "Erro de configuração"
        case is AIError: return "Erro na IA"
        case is CategorizationError: return "Erro na categorização"
        default: return "Erro inesperado"
        }
    }
}
