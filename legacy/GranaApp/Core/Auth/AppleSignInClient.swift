import AppKit
import AuthenticationServices
import CryptoKit
import Foundation

enum AppleSignInError: LocalizedError, Equatable {
    case alreadyInProgress
    case invalidCredential
    case missingIdentityToken
    case missingPresentationAnchor

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            "Já existe um login com Apple em andamento."
        case .invalidCredential:
            "A Apple não retornou uma credencial válida."
        case .missingIdentityToken:
            "A Apple não retornou o token de identidade necessário."
        case .missingPresentationAnchor:
            "Não foi possível abrir a janela de login da Apple."
        }
    }
}

@MainActor
final class AppleSignInClient: NSObject {
    private var continuation: CheckedContinuation<AppleSignInCredentials, any Error>?
    private weak var presentationAnchor: NSWindow?
    private var currentNonce: String?

    func signIn(presentationAnchor: NSWindow?) async throws -> AppleSignInCredentials {
        guard continuation == nil else {
            throw AppleSignInError.alreadyInProgress
        }
        guard let presentationAnchor else {
            throw AppleSignInError.missingPresentationAnchor
        }

        let nonce = Self.randomNonce()
        currentNonce = nonce
        self.presentationAnchor = presentationAnchor

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let request = ASAuthorizationAppleIDProvider().createRequest()
                request.requestedScopes = [.email, .fullName]
                request.nonce = Self.sha256(nonce)

                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
        } onCancel: {
            Task { @MainActor in
                finish(.failure(CancellationError()))
            }
        }
    }

    private func finish(_ result: Result<AppleSignInCredentials, any Error>) {
        let pending = continuation
        continuation = nil
        currentNonce = nil
        presentationAnchor = nil

        switch result {
        case let .success(credentials):
            pending?.resume(returning: credentials)
        case let .failure(error):
            pending?.resume(throwing: error)
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else {
                continue
            }
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInClient: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(AppleSignInError.invalidCredential))
            return
        }
        guard let identityToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
            finish(.failure(AppleSignInError.missingIdentityToken))
            return
        }

        let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        finish(.success(AppleSignInCredentials(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            fullName: credential.fullName?.formatted().trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            nonce: currentNonce
        )))
    }

    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        finish(.failure(error))
    }
}

extension AppleSignInClient: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor ?? NSApp.keyWindow ?? NSWindow()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
