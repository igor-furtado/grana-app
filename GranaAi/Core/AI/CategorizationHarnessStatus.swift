import Foundation
import Observation

@MainActor
@Observable
final class CategorizationHarnessStatusCenter {
    struct Issue: Equatable {
        let title: String
        let message: String
    }

    static let shared = CategorizationHarnessStatusCenter()

    private(set) var issue: Issue?

    private init() {}

    func markUnavailable(message: String) {
        issue = Issue(
            title: "Categorização online indisponível",
            message: message
        )
    }

    func clear() {
        issue = nil
    }
}

enum CategorizationHarnessSupport {
    static let recoveryMessage =
        "A categorização assistida vai cair em Não Classificado até o serviço online voltar a responder."

    static func isHarnessIssue(_ error: Error) -> Bool {
        if error is CategorizationRemoteRepositoryError {
            return true
        }
        guard let aiError = error as? AIError else { return false }
        switch aiError {
        case .invalidConfiguration, .requestFailed, .invalidResponse, .httpStatus,
             .responseParse, .decoding:
            return true
        case .authenticationRequired, .unknownCategorySlug, .cancelled:
            return false
        }
    }

    static func issue(for error: Error) -> CategorizationHarnessStatusCenter.Issue? {
        if let error = error as? CategorizationRemoteRepositoryError {
            switch error {
            case .quotaExceeded:
                return .init(
                    title: "Categorização online pausada",
                    message: "A chave remota da OpenAI ficou sem cota ou sem billing ativo. A importação continua com Não Classificado até a chave do projeto ser regularizada."
                )
            case let .rateLimited(retryAfterSeconds):
                let retryText: String
                if let retryAfterSeconds, retryAfterSeconds > 0 {
                    retryText = " Tente novamente em cerca de \(retryAfterSeconds) segundos."
                } else {
                    retryText = " Tente novamente em instantes."
                }
                return .init(
                    title: "Categorização online em limite",
                    message: "A OpenAI atingiu o limite de taxa do projeto remoto.\(retryText) A importação continua com Não Classificado."
                )
            case .invalidConfiguration:
                return .init(
                    title: "Categorização online incompleta",
                    message: "A configuração remota da categorização assistida está incompleta. A importação continua com Não Classificado até o projeto ser ajustado."
                )
            case .unsupportedProvider, .invalidRequest, .unavailable, .unexpectedResponse:
                return .init(
                    title: "Categorização online indisponível",
                    message: recoveryMessage
                )
            case .authenticationRequired:
                return nil
            }
        }

        guard isHarnessIssue(error) else { return nil }
        return .init(
            title: "Categorização online indisponível",
            message: recoveryMessage
        )
    }

    @MainActor
    static func recoveryAction() -> NoticeCenter.Action {
        NoticeCenter.Action(title: "Abrir Categorização") {
            AppSectionNavigation.open(.categorization)
        }
    }
}
