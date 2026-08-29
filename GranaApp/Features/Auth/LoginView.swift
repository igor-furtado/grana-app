import SwiftUI

struct LoginView: View {
    let authService: AuthService

    @State private var email = ""
    @State private var isSendingMagicLink = false

    var body: some View {
        HStack(spacing: GranaTheme.Spacing.lg) {
            storyPanel
            loginPanel
        }
        .frame(maxWidth: 1060)
        .padding(GranaTheme.Spacing.xl)
    }

    private var storyPanel: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xl) {
            logoMark

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                Text("GranaApp")
                    .font(GranaTheme.Typography.title1)
                    .foregroundStyle(GranaTheme.Palette.creamText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Acesse seu painel financeiro com uma sessão remota validada.")
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.creamText.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: GranaTheme.Spacing.xxl)

            HStack(spacing: GranaTheme.Spacing.xs) {
                pill("Sem senha fixa")
                pill("Online-only")
                pill("Fonte remota")
            }
        }
        .padding(GranaTheme.Spacing.xxl)
        .frame(maxWidth: .infinity, minHeight: 520, alignment: .leading)
        .background(
            GranaTheme.brandGradient(),
            in: RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                .strokeBorder(GranaTheme.Palette.creamText.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: GranaTheme.Shadow.accentColor, radius: 37, y: 16)
    }

    private var loginPanel: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                Text("Iniciar sessão")
                    .font(GranaTheme.Typography.title2)
                    .foregroundStyle(GranaTheme.Palette.ink)

                Text("Informe o e-mail para receber o magic link e voltar ao app com a sessão ativa.")
                    .font(GranaTheme.Typography.calloutEmphasis)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AppUI.TextField(
                label: "E-mail",
                text: $email,
                placeholder: "voce@exemplo.com",
                textAlignment: .trailing
            )

            Button(isSendingMagicLink ? "Enviando…" : "Enviar magic link") {
                Task {
                    await sendMagicLink()
                }
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(isSubmitDisabled)
            .opacity(isSubmitDisabled ? 0.55 : 1)

            Divider()
                .overlay(GranaTheme.Palette.line)

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                statusRow("E-mail", normalizedEmail.isEmpty ? "vazio" : normalizedEmail)
                statusRow("Envio", isSendingMagicLink ? "em andamento" : "aguardando")
            }
        }
        .padding(GranaTheme.Spacing.xxl)
        .frame(width: 420, alignment: .leading)
        .frame(minHeight: 520, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
    }

    private var logoMark: some View {
        Text("G")
            .font(GranaTheme.Typography.title3)
            .foregroundStyle(GranaTheme.Palette.creamText)
            .frame(width: 58, height: 58)
            .background(
                GranaTheme.Palette.creamText.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 21, style: .continuous)
            )
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(GranaTheme.Typography.footnoteEmphasis)
            .foregroundStyle(GranaTheme.Palette.creamText.opacity(0.86))
            .padding(.horizontal, GranaTheme.Spacing.sm)
            .padding(.vertical, GranaTheme.Spacing.xs)
            .background(GranaTheme.Palette.creamText.opacity(0.10), in: Capsule())
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(GranaTheme.Palette.muted)
            Spacer()
            Text(value)
                .foregroundStyle(GranaTheme.Palette.ink)
        }
        .font(GranaTheme.Typography.subheadlineEmphasis)
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSubmitDisabled: Bool {
        isSendingMagicLink || normalizedEmail.isEmpty
    }

    private func sendMagicLink() async {
        isSendingMagicLink = true
        defer { isSendingMagicLink = false }

        do {
            try await authService.requestMagicLink(email: normalizedEmail)
            NoticeCenter.shared.success(
                title: "Magic link enviado",
                message: "Abra o e-mail e volte para o app pelo link recebido."
            )
        } catch {
            NoticeCenter.shared.report(error, title: "Falha ao enviar magic link")
        }
    }
}
