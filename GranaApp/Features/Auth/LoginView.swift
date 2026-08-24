import SwiftUI

struct LoginView: View {
    let authService: AuthService

    @State private var email = ""
    @State private var isSendingMagicLink = false

    var body: some View {
        ZStack {
            GranaBackground()

            HStack(spacing: 18) {
                storyPanel
                loginPanel
            }
            .frame(maxWidth: 1060)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var storyPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            logoMark

            VStack(alignment: .leading, spacing: 16) {
                Text("GranaApp")
                    .font(.system(size: 54, weight: .black))
                    .foregroundStyle(GranaTheme.Palette.creamText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Acesse seu painel financeiro com uma sessão remota validada.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.creamText.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 28)

            HStack(spacing: 9) {
                pill("Sem senha fixa")
                pill("Online-only")
                pill("Fonte remota")
            }
        }
        .padding(34)
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
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Iniciar sessão")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(GranaTheme.Palette.ink)

                Text("Informe o e-mail para receber o magic link e voltar ao app com a sessão ativa.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("E-mail")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(GranaTheme.Palette.muted)

                TextField("voce@exemplo.com", text: $email)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 15)
                    .frame(height: 52)
                    .background(
                        GranaTheme.Palette.paper.opacity(0.86),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(GranaTheme.Palette.line, lineWidth: 1)
                    }
            }

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

            VStack(alignment: .leading, spacing: 8) {
                statusRow("E-mail", normalizedEmail.isEmpty ? "vazio" : normalizedEmail)
                statusRow("Envio", isSendingMagicLink ? "em andamento" : "aguardando")
            }
        }
        .padding(34)
        .frame(width: 420, alignment: .leading)
        .frame(minHeight: 520, alignment: .leading)
        .granaSurface(.glass, cornerRadius: GranaTheme.Radius.hero)
    }

    private var logoMark: some View {
        Text("G")
            .font(.system(size: 23, weight: .black))
            .foregroundStyle(GranaTheme.Palette.creamText)
            .frame(width: 58, height: 58)
            .background(
                GranaTheme.Palette.creamText.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 21, style: .continuous)
            )
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GranaTheme.Palette.creamText.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
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
        .font(.system(size: 13, weight: .semibold))
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
