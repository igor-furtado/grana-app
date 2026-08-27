import AppKit
import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isSigningOut = false

    var body: some View {
        Group {
            switch environment.authService.state {
            case let .authenticated(session):
                authenticatedContent(session)
            case .restoring:
                ProgressView("Restaurando sessão…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
    }

    private func authenticatedContent(_ session: AuthSessionContext) -> some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            FeatureScreenHeader(
                title: "Perfil",
                subtitle: headerSubtitle(for: session)
            ) {
                Button {
                    signOut()
                } label: {
                    if isSigningOut {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Sair", systemImage: AppIcon.signOut.systemImage)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(GranaPrimaryButtonStyle())
                .disabled(isSigningOut)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                    identityCard(session)
                    infoSection(
                        title: "Sessão",
                        icon: "lock.shield",
                        rows: sessionRows(for: session)
                    )
                    infoSection(
                        title: "Backend",
                        icon: AppIcon.sidebarInstitutions.systemImage,
                        rows: [backendRow]
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func identityCard(_ session: AuthSessionContext) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                profileBadge

                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text(displayName(for: session))
                        .font(GranaTheme.Typography.title3)
                        .foregroundStyle(GranaTheme.Palette.ink)

                    Text(displayValue(session.email))
                        .font(GranaTheme.Typography.subheadline)
                        .foregroundStyle(GranaTheme.Palette.muted)

                    providerBadgeText(session.providers)
                }

                Spacer(minLength: GranaTheme.Spacing.none)
            }

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                rowLabel("ID do usuário")

                HStack(spacing: GranaTheme.Spacing.sm) {
                    Text(session.userID.uuidString.lowercased())
                        .font(GranaTheme.Typography.code)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button {
                        copyUserID(session.userID)
                    } label: {
                        Label("Copiar ID do usuário", systemImage: AppIcon.copy.systemImage)
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(GranaSecondaryButtonStyle())
                    .help("Copiar ID do usuário")
                }
            }

            HStack(spacing: GranaTheme.Spacing.md) {
                compactFact(
                    title: "Criado em",
                    value: displayDate(session.createdAt)
                )
                compactFact(
                    title: "Último login",
                    value: displayDate(session.lastSignInAt)
                )
            }
        }
        .padding(GranaTheme.Spacing.lg)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
    }

    private func infoSection(
        title: String,
        icon: String,
        rows: [ProfileRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            HStack(spacing: GranaTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: GranaTheme.IconSize.medium))
                    .foregroundStyle(GranaTheme.Palette.tealDeep)

                Text(title)
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.ink)
            }

            VStack(spacing: GranaTheme.Spacing.sm) {
                ForEach(rows) { row in
                    infoRow(row)
                }
            }
        }
        .padding(GranaTheme.Spacing.md)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }

    private func infoRow(_ row: ProfileRow) -> some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
            Text(row.title)
                .font(GranaTheme.Typography.caption1Emphasis)
                .foregroundStyle(GranaTheme.Palette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            if row.usesCodeFont {
                valueText(row)
                    .font(GranaTheme.Typography.code)
                    .textSelection(.enabled)
            } else {
                valueText(row)
                    .font(GranaTheme.Typography.body)
                    .textSelection(.disabled)
            }
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .padding(.vertical, GranaTheme.Spacing.sm)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
    }

    private func valueText(_ row: ProfileRow) -> some View {
        Text(row.value)
            .foregroundStyle(row.accent ?? GranaTheme.Palette.ink)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var profileBadge: some View {
        ZStack {
            Circle()
                .fill(GranaTheme.brandGradient())

            Image(systemName: AppIcon.sidebarProfile.systemImage)
                .font(.system(size: GranaTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(GranaTheme.Palette.creamText)
        }
        .frame(width: 64, height: 64)
        .shadow(color: GranaTheme.Shadow.accentColor, radius: 16, y: 10)
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(GranaTheme.Typography.caption1Emphasis)
            .foregroundStyle(GranaTheme.Palette.muted)
    }

    private func providerBadgeText(_ providers: [String]) -> some View {
        Text(providersText(providers))
            .font(GranaTheme.Typography.caption1Emphasis)
            .foregroundStyle(GranaTheme.Palette.tealDeep)
            .padding(.horizontal, GranaTheme.Spacing.xs)
            .padding(.vertical, GranaTheme.Spacing.xxs)
            .background(GranaTheme.Palette.teal.opacity(0.10), in: Capsule())
    }

    private func compactFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
            Text(title)
                .font(GranaTheme.Typography.caption2Emphasis)
                .foregroundStyle(GranaTheme.Palette.muted)

            Text(value)
                .font(GranaTheme.Typography.subheadline)
                .foregroundStyle(GranaTheme.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerSubtitle(for session: AuthSessionContext) -> String {
        let name = displayName(for: session)
        let email = displayValue(session.email)
        if name == "Não informado" {
            return email
        }
        return email == "Não informado" ? name : "\(name) · \(email)"
    }

    private func sessionRows(for session: AuthSessionContext) -> [ProfileRow] {
        [
            ProfileRow(title: "Status", value: "Autenticado", accent: GranaTheme.Palette.green),
            ProfileRow(title: "Provedores", value: providersText(session.providers)),
            ProfileRow(title: "Último login", value: displayDate(session.lastSignInAt)),
            ProfileRow(title: "Expira em", value: displayDate(session.expiresAt)),
        ]
    }

    private var backendRow: ProfileRow {
        let isAvailable = environment.availabilityState == .available
        return ProfileRow(
            title: "Status",
            value: isAvailable ? "Disponível" : "Indisponível",
            accent: isAvailable ? GranaTheme.Palette.green : GranaTheme.Palette.red
        )
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

private struct ProfileRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    var accent: Color?
    var usesCodeFont = false
}
