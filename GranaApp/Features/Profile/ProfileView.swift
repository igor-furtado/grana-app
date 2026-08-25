import AppKit
import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isSigningOut = false

    var body: some View {
        Form {
            switch environment.authService.state {
            case let .authenticated(session):
                userSection(session)
                sessionSection(session)
                availabilitySection
                actionsSection
            case .restoring:
                ProgressView("Restaurando sessão…")
            case .unavailable:
                EmptyStateView(
                    "Backend indisponível",
                    icon: .sidebarProfile,
                    description: "Tente novamente para validar sua sessão e carregar o perfil."
                )
            case .unauthenticated:
                EmptyStateView(
                    "Sem sessão",
                    icon: .sidebarProfile,
                    description: "Entre novamente para ver os dados do perfil."
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Perfil")
    }

    private func userSection(_ session: AuthSessionContext) -> some View {
        Section("Usuário") {
            LabeledContent("Nome", value: displayName(for: session))
            LabeledContent("Email", value: displayValue(session.email))
            LabeledContent("ID do usuário") {
                HStack(spacing: GranaTheme.Spacing.xs) {
                    Text(session.userID.uuidString.lowercased())
                        .font(GranaTheme.Typography.code)
                        .textSelection(.enabled)
                    Button {
                        copyUserID(session.userID)
                    } label: {
                        Label("Copiar ID do usuário", systemImage: AppIcon.copy.systemImage)
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("Copiar ID do usuário")
                }
            }
            LabeledContent("Criado em", value: displayDate(session.createdAt))
        }
    }

    private func sessionSection(_ session: AuthSessionContext) -> some View {
        Section("Sessão") {
            LabeledContent("Status", value: "Autenticado")
            LabeledContent("Provedores", value: providersText(session.providers))
            LabeledContent("Último login", value: displayDate(session.lastSignInAt))
            LabeledContent("Expira em", value: displayDate(session.expiresAt))
        }
    }

    private var availabilitySection: some View {
        Section("Backend") {
            LabeledContent(
                "Status",
                value: environment.availabilityState == .available ? "Disponível" : "Indisponível"
            )
        }
    }

    private var actionsSection: some View {
        Section("Ações") {
            Button {
                signOut()
            } label: {
                Label("Sair", systemImage: AppIcon.signOut.systemImage)
            }
            .disabled(isSigningOut)
        }
    }

    private func signOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        Task {
            defer { isSigningOut = false }
            do {
                try await environment.authService.signOut()
            } catch {
                NoticeCenter.shared.report(error, title: "Falha ao sair")
            }
        }
    }

    private func copyUserID(_ userID: UUID) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(userID.uuidString.lowercased(), forType: .string)
        NoticeCenter.shared.success(title: "ID copiado")
    }

    private func displayName(for session: AuthSessionContext) -> String {
        displayValue(session.displayName)
    }

    private func displayValue(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return "Não informado"
        }
        return value
    }

    private func providersText(_ providers: [String]) -> String {
        let formatted = providers
            .map(formattedProvider(_:))
            .filter { !$0.isEmpty }
        guard !formatted.isEmpty else { return "Não informado" }
        return formatted.joined(separator: ", ")
    }

    private func formattedProvider(_ provider: String) -> String {
        switch provider.lowercased() {
        case "email": "Email"
        case "google": "Google"
        case "github": "GitHub"
        case "apple": "Apple"
        default: provider.capitalized
        }
    }

    private func displayDate(_ date: Date?) -> String {
        guard let date else { return "Não informado" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
