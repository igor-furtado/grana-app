import AppKit
import AppUI
import AuthenticationServices
import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isSigningOut = false
    @State private var appleSignInClient = AppleSignInClient()

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
        VStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Layout.ScreenHeader(
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
                        Label("Sair", systemImage: AppUI.Icon.signOut.systemImage)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(GranaPrimaryButtonStyle())
                .disabled(isSigningOut)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
                    identityCard(session)
                    infoSection(
                        title: "Sessão",
                        icon: "lock.shield",
                        rows: sessionRows(for: session)
                    )
                    accessLinkingSection(session)
                    infoSection(
                        title: "Backend",
                        icon: AppUI.Icon.sidebarInstitutions.systemImage,
                        rows: [backendRow]
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func identityCard(_ session: AuthSessionContext) -> some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.lg) {
            HStack(alignment: .top, spacing: AppUI.Theme.Spacing.md) {
                profileBadge

                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                    Text(displayName(for: session))
                        .font(AppUI.Theme.Typography.title3)
                        .foregroundStyle(AppUI.Theme.Palette.ink)

                    Text(displayValue(session.email))
                        .font(AppUI.Theme.Typography.subheadline)
                        .foregroundStyle(AppUI.Theme.Palette.muted)

                    providerBadgeText(session.providers)
                }

                Spacer(minLength: AppUI.Theme.Spacing.none)
            }

            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
                rowLabel("ID do usuário")

                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    Text(session.userID.uuidString.lowercased())
                        .font(AppUI.Theme.Typography.code)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button {
                        copyUserID(session.userID)
                    } label: {
                        Label("Copiar ID do usuário", systemImage: AppUI.Icon.copy.systemImage)
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(GranaSecondaryButtonStyle())
                    .help("Copiar ID do usuário")
                }
            }

            HStack(spacing: AppUI.Theme.Spacing.md) {
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
        .padding(AppUI.Theme.Spacing.lg)
        .granaSurface(.subtle, cornerRadius: AppUI.Theme.Radius.hero)
    }

    private func infoSection(
        title: String,
        icon: String,
        rows: [ProfileRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
            HStack(spacing: AppUI.Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: AppUI.Theme.IconSize.medium))
                    .foregroundStyle(AppUI.Theme.Palette.tealDeep)

                Text(title)
                    .font(AppUI.Theme.Typography.headline)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
            }

            VStack(spacing: AppUI.Theme.Spacing.sm) {
                ForEach(rows) { row in
                    infoRow(row)
                }
            }
        }
        .padding(AppUI.Theme.Spacing.md)
        .granaSurface(.subtle, cornerRadius: AppUI.Theme.Radius.card)
    }

    private func infoRow(_ row: ProfileRow) -> some View {
        HStack(alignment: .top, spacing: AppUI.Theme.Spacing.md) {
            Text(row.title)
                .font(AppUI.Theme.Typography.caption1Emphasis)
                .foregroundStyle(AppUI.Theme.Palette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            if row.usesCodeFont {
                valueText(row)
                    .font(AppUI.Theme.Typography.code)
                    .textSelection(.enabled)
            } else {
                valueText(row)
                    .font(AppUI.Theme.Typography.body)
                    .textSelection(.disabled)
            }
        }
        .padding(.horizontal, AppUI.Theme.Spacing.md)
        .padding(.vertical, AppUI.Theme.Spacing.sm)
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
    }

    private func accessLinkingSection(_ session: AuthSessionContext) -> some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
            HStack(spacing: AppUI.Theme.Spacing.xs) {
                Image(systemName: "person.badge.key")
                    .font(.system(size: AppUI.Theme.IconSize.medium))
                    .foregroundStyle(AppUI.Theme.Palette.tealDeep)

                Text("Métodos de acesso")
                    .font(AppUI.Theme.Typography.headline)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
            }

            if case let .linkingPrompt(method, email) = environment.authService.loginState {
                accessLinkingPrompt(method: method, email: email)
            } else if isLinkingAccess {
                ProgressView(accessLinkingProgressTitle)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
                    .padding(AppUI.Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
            } else if hasProvider("apple", in: session) {
                infoRow(ProfileRow(title: "Apple", value: "Vinculado", accent: AppUI.Theme.Palette.green))
            } else {
                Button {
                    linkAppleAccess()
                } label: {
                    Label("Vincular Apple", systemImage: "apple.logo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GranaSecondaryButtonStyle())
                .disabled(isAuthBusy)
            }
        }
        .padding(AppUI.Theme.Spacing.md)
        .granaSurface(.subtle, cornerRadius: AppUI.Theme.Radius.card)
    }

    private func accessLinkingPrompt(method: AuthService.AccessLinkingMethod, email: String?) -> some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            Text(accessLinkingPromptTitle(method: method, email: email))
                .font(AppUI.Theme.Typography.subheadlineEmphasis)
                .foregroundStyle(AppUI.Theme.Palette.ink)

            HStack(spacing: AppUI.Theme.Spacing.sm) {
                Button("Confirmar") {
                    confirmAccessLink()
                }
                .buttonStyle(GranaPrimaryButtonStyle())

                Button("Cancelar") {
                    environment.authService.cancelAccessLink()
                }
                .buttonStyle(GranaSecondaryButtonStyle())
            }
        }
        .padding(AppUI.Theme.Spacing.md)
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
    }

    private func valueText(_ row: ProfileRow) -> some View {
        Text(row.value)
            .foregroundStyle(row.accent ?? AppUI.Theme.Palette.ink)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var profileBadge: some View {
        ZStack {
            Circle()
                .fill(AppUI.Theme.brandGradient())

            Image(systemName: AppUI.Icon.sidebarProfile.systemImage)
                .font(.system(size: AppUI.Theme.IconSize.large, weight: .semibold))
                .foregroundStyle(AppUI.Theme.Palette.creamText)
        }
        .frame(width: 64, height: 64)
        .shadow(color: AppUI.Theme.Shadow.accentColor, radius: 16, y: 10)
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(AppUI.Theme.Typography.caption1Emphasis)
            .foregroundStyle(AppUI.Theme.Palette.muted)
    }

    private func providerBadgeText(_ providers: [String]) -> some View {
        Text(providersText(providers))
            .font(AppUI.Theme.Typography.caption1Emphasis)
            .foregroundStyle(AppUI.Theme.Palette.tealDeep)
            .padding(.horizontal, AppUI.Theme.Spacing.xs)
            .padding(.vertical, AppUI.Theme.Spacing.xxs)
            .background(AppUI.Theme.Palette.teal.opacity(0.10), in: Capsule())
    }

    private func compactFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
            Text(title)
                .font(AppUI.Theme.Typography.caption2Emphasis)
                .foregroundStyle(AppUI.Theme.Palette.muted)

            Text(value)
                .font(AppUI.Theme.Typography.subheadline)
                .foregroundStyle(AppUI.Theme.Palette.ink)
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
            ProfileRow(title: "Status", value: "Autenticado", accent: AppUI.Theme.Palette.green),
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
            accent: isAvailable ? AppUI.Theme.Palette.green : AppUI.Theme.Palette.red
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

    private func linkAppleAccess() {
        Task {
            do {
                let credentials = try await appleSignInClient.signIn(presentationAnchor: NSApp.keyWindow)
                try await environment.authService.signInWithApple(credentials)
            } catch {
                if error is CancellationError || isAppleCancellation(error) {
                    environment.authService.cancelAccessLink()
                    return
                }
                NoticeCenter.shared.report(error, title: "Falha ao preparar vinculação")
            }
        }
    }

    private func confirmAccessLink() {
        Task {
            do {
                try await environment.authService.confirmAccessLink()
                NoticeCenter.shared.success(title: "Método vinculado")
            } catch {
                NoticeCenter.shared.report(error, title: "Falha ao vincular acesso")
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

    private var isAuthBusy: Bool {
        switch environment.authService.loginState {
        case .signingInWithApple, .sendingOTP, .verifyingOTP, .linkingAccess:
            true
        case .idle, .enteringEmail, .awaitingOTP, .authenticated, .linkingPrompt, .failure:
            false
        }
    }

    private var isLinkingAccess: Bool {
        if case .linkingAccess = environment.authService.loginState {
            true
        } else {
            false
        }
    }

    private var accessLinkingProgressTitle: String {
        if case let .linkingAccess(method) = environment.authService.loginState {
            return "Vinculando \(method.displayName)..."
        }
        return "Vinculando..."
    }

    private func accessLinkingPromptTitle(method: AuthService.AccessLinkingMethod, email: String?) -> String {
        if let email {
            return "Confirmar vinculação com \(method.displayName) para \(email)?"
        }
        return "Confirmar vinculação com \(method.displayName)?"
    }

    private func hasProvider(_ provider: String, in session: AuthSessionContext) -> Bool {
        session.providers.contains { $0.caseInsensitiveCompare(provider) == .orderedSame }
    }

    private func isAppleCancellation(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == ASAuthorizationError.errorDomain
            && nsError.code == ASAuthorizationError.canceled.rawValue
    }

    private func displayDate(_ date: Date?) -> String {
        guard let date else { return "Não informado" }
        return GranaDateFormat.dateTime(date)
    }
}

private struct ProfileRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    var accent: Color?
    var usesCodeFont = false
}
