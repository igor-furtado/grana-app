import Foundation

/// Protocolo opcional pra erros que querem controlar o **título** exibido no
/// toast global. Sem implementar, o `NoticeCenter` cai num título genérico
/// derivado do tipo do erro ("DatabaseError", "ImportError", …).
///
/// A *mensagem* sempre vem de `LocalizedError.errorDescription`, então os
/// enums de domínio já existentes (`DatabaseError`, `ImportError`, `AIError`,
/// `CategorizationError`) funcionam sem precisar conformar a este protocolo.
protocol UserFacingError: LocalizedError {
    /// Cabeçalho curto do toast. Padrão: nome legível do caso.
    var errorTitle: String { get }
}

enum AppConfigurationError: UserFacingError {
    case placeholderValue(String)
    case invalidURL(String)

    var errorTitle: String {
        "Configuração inválida"
    }

    var errorDescription: String? {
        switch self {
        case let .placeholderValue(key):
            return "Preencha \(key) com o valor real antes de usar este recurso."
        case let .invalidURL(key):
            return "A URL informada em \(key) é inválida."
        }
    }
}

enum AppConfigurationValidator {
    static func supabaseURL(_ rawValue: String) throws -> URL {
        try validatedURL(
            rawValue,
            key: "Config.supabaseURL",
            placeholderMarkers: [
                "your_project",
                "your-project",
            ]
        )
    }

    static func supabaseAnonKey(_ rawValue: String) throws -> String {
        try validatedValue(
            rawValue,
            key: "Config.supabaseAnonKey",
            placeholderMarkers: [
                "your_anon_key",
                "your-anon-key",
            ]
        )
    }

    static func powerSyncURL(_ rawValue: String) throws -> String {
        _ = try validatedURL(
            rawValue,
            key: "Config.powerSyncURL",
            placeholderMarkers: [
                "your_instance",
                "your-instance",
            ]
        )
        return rawValue
    }

    private static func validatedURL(
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

    private static func validatedValue(
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
        let message: String
        if let localized = error as? LocalizedError, let desc = localized.errorDescription {
            message = desc
        } else {
            message = (error as NSError).localizedDescription
        }

        let title: String = {
            if let overrideTitle { return overrideTitle }
            if let userFacing = error as? UserFacingError { return userFacing.errorTitle }
            return defaultTitle(for: error)
        }()

        return AppErrorPresentation(title: title, message: message)
    }

    /// Título "amigável" derivado do tipo. Mapeia os enums conhecidos pra
    /// rótulos em PT-BR; tipos desconhecidos viram "Erro inesperado".
    private static func defaultTitle(for error: Error) -> String {
        switch error {
        case is DatabaseError: return "Erro no banco"
        case is ImportError: return "Erro na importação"
        case is AppConfigurationError: return "Erro de configuração"
        case is AIError: return "Erro na IA"
        case is CategorizationError: return "Erro na categorização"
        default: return "Erro inesperado"
        }
    }
}
