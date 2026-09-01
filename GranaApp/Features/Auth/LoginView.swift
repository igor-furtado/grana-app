import AppKit
import AppUI
import AuthenticationServices
import SwiftUI

struct LoginView: View {
    let authService: AuthService

    @State private var email = ""
    @State private var code = ""
    @State private var appleSignInClient = AppleSignInClient()

    var body: some View {
        HStack(spacing: AppUI.Theme.Spacing.xxl) {
            brandSide

            Rectangle()
                .fill(AppUI.Theme.Palette.line)
                .frame(width: 1, height: 260)

            authSide
        }
        .padding(AppUI.Theme.Spacing.xxxl)
        .frame(maxWidth: 980, minHeight: 480)
        .granaSurface(.glass, cornerRadius: AppUI.Theme.Radius.card)
        .padding(AppUI.Theme.Spacing.xl)
    }

    private var brandSide: some View {
        VStack(alignment: .center, spacing: AppUI.Theme.Spacing.xl) {
            logoMark

            VStack(spacing: AppUI.Theme.Spacing.xs) {
                Text("GranaApp")
                    .font(AppUI.Theme.Typography.title2)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("Seu painel financeiro pessoal.")
                    .font(AppUI.Theme.Typography.calloutEmphasis)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var authSide: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
                Text("Entrar")
                    .font(AppUI.Theme.Typography.title2)
                    .foregroundStyle(AppUI.Theme.Palette.ink)

                Text("Escolha um método de acesso.")
                    .font(AppUI.Theme.Typography.calloutEmphasis)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }

            Button {
                Task {
                    await signInWithApple()
                }
            } label: {
                Label(appleButtonTitle, systemImage: "apple.logo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(isBusy)
            .opacity(isBusy ? 0.55 : 1)

            divider

            emailAccess

            statusText
                .frame(minHeight: 20, alignment: .leading)
        }
        .frame(width: 390, alignment: .leading)
    }

    private var emailAccess: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            if isEmailFormVisible {
                AppUI.TextField(
                    label: "E-mail",
                    text: $email,
                    placeholder: "voce@exemplo.com",
                    leadingSystemImage: "envelope",
                    showsClearButton: true
                )
                .disabled(isBusy || isAwaitingOTP || isVerifyingOTP)

                if isAwaitingOTP || isVerifyingOTP {
                    AppUI.TextField(
                        label: "Código",
                        text: $code,
                        placeholder: "123456",
                        leadingSystemImage: "number",
                        font: AppUI.Theme.Typography.code,
                        textAlignment: .trailing
                    )
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter(\.isNumber).prefix(6))
                    }
                }

                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    Button(emailButtonTitle) {
                        Task {
                            await handleEmailAction()
                        }
                    }
                    .buttonStyle(GranaSecondaryButtonStyle())
                    .disabled(isEmailActionDisabled)
                    .opacity(isEmailActionDisabled ? 0.55 : 1)

                    if isAwaitingOTP || isVerifyingOTP {
                        Button("Trocar e-mail") {
                            code = ""
                            authService.beginEmailEntry()
                        }
                        .buttonStyle(.plain)
                        .font(AppUI.Theme.Typography.calloutEmphasis)
                        .foregroundStyle(AppUI.Theme.Palette.tealDeep)
                        .disabled(isBusy)
                    }
                }
            } else {
                Button("Entrar com e-mail") {
                    authService.beginEmailEntry()
                }
                .buttonStyle(.plain)
                .font(AppUI.Theme.Typography.calloutEmphasis)
                .foregroundStyle(AppUI.Theme.Palette.tealDeep)
                .disabled(isBusy)
            }
        }
    }

    private var divider: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            Rectangle()
                .fill(AppUI.Theme.Palette.line)
                .frame(height: 1)
            Text("ou")
                .font(AppUI.Theme.Typography.footnoteEmphasis)
                .foregroundStyle(AppUI.Theme.Palette.muted)
            Rectangle()
                .fill(AppUI.Theme.Palette.line)
                .frame(height: 1)
        }
    }

    private var statusText: some View {
        Text(statusMessage)
            .font(AppUI.Theme.Typography.subheadlineEmphasis)
            .foregroundStyle(statusColor)
    }

    private var logoMark: some View {
        Text("G")
            .font(AppUI.Theme.Typography.title3)
            .foregroundStyle(AppUI.Theme.Palette.creamText)
            .frame(width: 58, height: 58)
            .background(
                AppUI.Theme.brandGradient(),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: AppUI.Theme.Shadow.accentColor, radius: 18, y: 8)
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedCode: String {
        String(code.filter(\.isNumber).prefix(6))
    }

    private var isBusy: Bool {
        switch authService.loginState {
        case .signingInWithApple, .sendingOTP, .verifyingOTP:
            true
        case .idle, .enteringEmail, .awaitingOTP, .authenticated, .linkingPrompt, .failure:
            false
        }
    }

    private var isEmailFormVisible: Bool {
        switch authService.loginState {
        case .enteringEmail, .sendingOTP, .awaitingOTP, .verifyingOTP, .failure:
            true
        case .idle, .signingInWithApple, .authenticated, .linkingPrompt:
            false
        }
    }

    private var isEmailActionDisabled: Bool {
        if isBusy || normalizedEmail.isEmpty {
            return true
        }
        if isAwaitingOTP || isVerifyingOTP {
            return normalizedCode.count != 6
        }
        return false
    }

    private var appleButtonTitle: String {
        authService.loginState == .signingInWithApple ? "Abrindo Apple..." : "Continuar com Apple"
    }

    private var emailButtonTitle: String {
        switch authService.loginState {
        case .sendingOTP:
            "Enviando..."
        case .awaitingOTP:
            "Verificar código"
        case .verifyingOTP:
            "Verificando..."
        default:
            "Enviar código"
        }
    }

    private var statusMessage: String {
        switch authService.loginState {
        case .signingInWithApple:
            "Abrindo Apple..."
        case .sendingOTP:
            "Enviando código..."
        case .awaitingOTP:
            "Código enviado."
        case .verifyingOTP:
            "Verificando código..."
        case .authenticated:
            "Sessão autenticada."
        case .linkingPrompt:
            "Confirme a vinculação."
        case let .failure(message):
            message
        case .idle, .enteringEmail:
            ""
        }
    }

    private var statusColor: Color {
        if case .failure = authService.loginState {
            AppUI.Theme.Palette.red
        } else {
            AppUI.Theme.Palette.muted
        }
    }

    private var isAwaitingOTP: Bool {
        if case .awaitingOTP = authService.loginState {
            true
        } else {
            false
        }
    }

    private var isVerifyingOTP: Bool {
        if case .verifyingOTP = authService.loginState {
            true
        } else {
            false
        }
    }

    private func signInWithApple() async {
        do {
            let credentials = try await appleSignInClient.signIn(presentationAnchor: NSApp.keyWindow)
            try await authService.signInWithApple(credentials)
        } catch {
            if error is CancellationError || isAppleCancellation(error) {
                authService.resetLoginState()
                return
            }
            NoticeCenter.shared.report(error, title: "Falha ao entrar com Apple")
        }
    }

    private func handleEmailAction() async {
        if isAwaitingOTP {
            await verifyEmailOTP()
        } else {
            await requestEmailOTP()
        }
    }

    private func requestEmailOTP() async {
        do {
            try await authService.requestEmailOTP(email: normalizedEmail)
            NoticeCenter.shared.success(
                title: "Código enviado",
                message: "Informe o código de 6 dígitos recebido por e-mail."
            )
        } catch {
            NoticeCenter.shared.report(error, title: "Falha ao enviar código")
        }
    }

    private func verifyEmailOTP() async {
        do {
            try await authService.verifyEmailOTP(email: normalizedEmail, code: normalizedCode)
        } catch {
            NoticeCenter.shared.report(error, title: "Falha ao verificar código")
        }
    }

    private func isAppleCancellation(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == ASAuthorizationError.errorDomain
            && nsError.code == ASAuthorizationError.canceled.rawValue
    }
}
