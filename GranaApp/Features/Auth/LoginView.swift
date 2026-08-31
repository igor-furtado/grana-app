import SwiftUI
import AppUI

struct LoginView: View {
    let authService: AuthService

    @State private var email = ""
    @State private var isSendingMagicLink = false

    var body: some View {
        HStack(spacing: AppUI.Theme.Spacing.lg) {
            storyPanel
            loginPanel
        }
        .frame(maxWidth: 1060)
        .padding(AppUI.Theme.Spacing.xl)
    }

    private var storyPanel: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xl) {
            logoMark

            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
                Text("GranaApp")
                    .font(AppUI.Theme.Typography.title1)
                    .foregroundStyle(AppUI.Theme.Palette.creamText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Acesse seu painel financeiro com uma sessão remota validada.")
                    .font(AppUI.Theme.Typography.headline)
                    .foregroundStyle(AppUI.Theme.Palette.creamText.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppUI.Theme.Spacing.xxl)

            HStack(spacing: AppUI.Theme.Spacing.xs) {
                pill("Sem senha fixa")
                pill("Online-only")
                pill("Fonte remota")
            }
        }
        .padding(AppUI.Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, minHeight: 520, alignment: .leading)
        .background(
            AppUI.Theme.brandGradient(),
            in: RoundedRectangle(cornerRadius: AppUI.Theme.Radius.hero, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppUI.Theme.Radius.hero, style: .continuous)
                .strokeBorder(AppUI.Theme.Palette.creamText.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: AppUI.Theme.Shadow.accentColor, radius: 37, y: 16)
    }

    private var loginPanel: some View {
        AppUI.Form.Shell {
            AppUI.Form.Header(
                title: "Iniciar sessão",
                subtitle: "Informe o e-mail para receber o magic link e voltar ao app com a sessão ativa."
            )

            Form {
                Section {
                    AppUI.TextField(
                        label: "E-mail",
                        text: $email,
                        placeholder: "voce@exemplo.com",
                        textAlignment: .trailing
                    )
                } header: {
                    AppUI.Form.SectionHeader(title: "Acesso")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)

            AppUI.Form.Actions {
                Button(isSendingMagicLink ? "Enviando…" : "Enviar magic link") {
                    Task {
                        await sendMagicLink()
                    }
                }
                .buttonStyle(GranaPrimaryButtonStyle())
                .disabled(isSubmitDisabled)
                .opacity(isSubmitDisabled ? 0.55 : 1)
            }

            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
                statusRow("E-mail", normalizedEmail.isEmpty ? "vazio" : normalizedEmail)
                statusRow("Envio", isSendingMagicLink ? "em andamento" : "aguardando")
            }
            .padding(.horizontal, AppUI.Theme.Spacing.lg)
        }
        .frame(width: 420, alignment: .leading)
        .frame(minHeight: 520, alignment: .leading)
    }

    private var logoMark: some View {
        Text("G")
            .font(AppUI.Theme.Typography.title3)
            .foregroundStyle(AppUI.Theme.Palette.creamText)
            .frame(width: 58, height: 58)
            .background(
                AppUI.Theme.Palette.creamText.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 21, style: .continuous)
            )
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(AppUI.Theme.Typography.footnoteEmphasis)
            .foregroundStyle(AppUI.Theme.Palette.creamText.opacity(0.86))
            .padding(.horizontal, AppUI.Theme.Spacing.sm)
            .padding(.vertical, AppUI.Theme.Spacing.xs)
            .background(AppUI.Theme.Palette.creamText.opacity(0.10), in: Capsule())
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(AppUI.Theme.Palette.muted)
            Spacer()
            Text(value)
                .foregroundStyle(AppUI.Theme.Palette.ink)
        }
        .font(AppUI.Theme.Typography.subheadlineEmphasis)
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
