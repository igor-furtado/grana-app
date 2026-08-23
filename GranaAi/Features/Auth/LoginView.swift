import SwiftUI

struct LoginView: View {
    let authService: AuthService

    @State private var email = ""
    @State private var isSendingMagicLink = false

    var body: some View {
        ZStack {
            backgroundView
                .ignoresSafeArea()

            loginCard
                .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            HStack(alignment: .top, spacing: 20) {
                leftPanel
                rightPanel
            }
        }
        .padding(36)
        .frame(maxWidth: 1040)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.78),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Acesso ao cofre")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("Conecte seu workspace financeiro")
                    .font(.system(size: 30, weight: .bold, design: .serif))

                Text("Uma única ação valida sua sessão remota e libera o acesso ao backend financeiro.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 520, alignment: .leading)
            }

            Spacer()

            Label("Sem senha fixa", systemImage: "key.slash.fill")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepCard(
                title: "1. Informe o e-mail",
                message: "O link volta para este Mac e conclui a sessão no próprio app.",
                icon: "envelope.fill"
            )
            stepCard(
                title: "2. Abra o magic link",
                message: "A autenticação é retomada pelo URL scheme configurado para o Grana AI.",
                icon: "link.circle.fill"
            )
            stepCard(
                title: "3. Entre na área financeira",
                message: "Depois da sessão válida, o app inicializa seu perfil remoto e libera a navegação.",
                icon: "checkmark.seal.fill"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Iniciar sessão")
                .font(.title3.weight(.semibold))

            TextField("voce@exemplo.com", text: $email)
                .textFieldStyle(.roundedBorder)

            Button(isSendingMagicLink ? "Enviando…" : "Enviar magic link") {
                Task {
                    await sendMagicLink()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSubmitDisabled)

            Divider()

            Text("Estado atual")
                .font(.headline)
            Text("Email: \(normalizedEmail.isEmpty ? "vazio" : normalizedEmail)")
                .foregroundStyle(.secondary)
            Text("Envio em andamento: \(isSendingMagicLink ? "sim" : "não")")
                .foregroundStyle(.secondary)
        }
        .frame(width: 360, alignment: .leading)
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.accentColor.opacity(0.09),
                Color(nsColor: .underPageBackgroundColor),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

    private func stepCard(
        title: String,
        message: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.accent)

            Text(title)
                .font(.headline)

            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
