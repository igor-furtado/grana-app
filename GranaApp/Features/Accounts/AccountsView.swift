import Foundation
import SwiftUI

struct AccountsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: AccountStore?
    @State private var formMode: FormMode?
    @State private var showArchived = false
    @State private var selectedAccountId: UUID?
    @State private var showDeleteConfirm = false

    /// `Identifiable` pra alimentar o `.sheet(item:)` — o id distingue
    /// "novo" de cada edição específica, garantindo que trocar de "editar
    /// conta A" pra "editar conta B" remonte o form (estado limpo).
    enum FormMode: Identifiable {
        case create
        case edit(Account)

        var id: String {
            switch self {
            case .create: return "create"
            case let .edit(account): return "edit-\(account.id.uuidString)"
            }
        }
    }

    var body: some View {
        Group {
            if let store {
                content(store: store)
                    .task { await store.load() }
            } else {
                ProgressView()
                    .task { store = AccountStore(container: environment.container) }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
    }

    private func content(store: AccountStore) -> some View {
        let visibleAccounts = visible(store: store)
        return VStack(spacing: GranaTheme.Spacing.sm) {
            header(store: store, visibleCount: visibleAccounts.count)

            Group {
                if visibleAccounts.isEmpty {
                    // Fora do `ScrollView` pra que `maxHeight: .infinity`
                    // centralize verticalmente no espaço disponível — dentro
                    // de um ScrollView a altura é intrínseca e o estado vazio
                    // gruda no topo.
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    grid(store: store, accounts: visibleAccounts)
                }
            }
        }
        .granaPagePadding()
        // Form sheet aparece centralizado e dimming no fundo — padrão macOS
        // pra create/edit. `.sheet(item:)` re-monta o conteúdo a cada novo
        // `formMode` (id muda), garantindo estado limpo entre aberturas.
        .sheet(item: $formMode) { mode in
            AccountFormView(
                existing: editingAccount(from: mode),
                lockedType: .checking,
                onCancel: { formMode = nil },
                onSaved: { formMode = nil }
            )
            .environment(store)
        }
        .confirmationDialog(
            "Apagar conta?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Apagar", role: .destructive) {
                guard let id = selectedAccountId else { return }
                Task {
                    do {
                        try await store.delete(id: id)
                    } catch {
                        NoticeCenter.shared.report(error)
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(
                "A conta só será apagada se não houver transações, faturas ou lotes de importação vinculados."
            )
        }
        .onChange(of: visibleAccounts.map(\.id)) { _, ids in
            reconcileSelection(visibleIds: ids)
        }
    }

    private func header(store: AccountStore, visibleCount: Int) -> some View {
        FeatureScreenHeader(
            title: "Contas",
            subtitle: accountsSubtitle(store: store, visibleCount: visibleCount)
        ) {
            Button {
                formMode = .create
            } label: {
                Label("Nova conta", systemImage: AppIcon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())

            if hasArchivedAccount {
                Menu {
                    Toggle("Mostrar arquivadas", isOn: $showArchived)
                } label: {
                    Label("Mais", systemImage: AppIcon.more.systemImage)
                }
                .buttonStyle(GranaSecondaryButtonStyle())
            }
        }
    }

    private func grid(store: AccountStore, accounts: [Account]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: GranaTheme.Spacing.md)],
                spacing: GranaTheme.Spacing.md
            ) {
                ForEach(accounts) { account in
                    AccountCard(
                        account: account,
                        displayName: store.displayName(for: account),
                        institution: store.institution(forAccount: account),
                        currentBalance: store.currentBalance(for: account),
                        isSelected: account.id == selectedAccountId,
                        onSelect: { selectedAccountId = account.id },
                        onEdit: {
                            selectedAccountId = account.id
                            formMode = .edit(account)
                        },
                        onToggleArchive: {
                            Task {
                                do {
                                    try await store.setArchived(account, archived: !account.archived)
                                } catch {
                                    NoticeCenter.shared.report(error)
                                }
                            }
                        },
                        onRequestDelete: {
                            selectedAccountId = account.id
                            showDeleteConfirm = true
                        }
                    )
                }
            }
        }
    }

    /// `true` quando pelo menos uma conta corrente está arquivada. Gateia a
    /// exibição do toggle "Mostrar arquivadas" — esconde quando não há nada
    /// arquivado no escopo desta tela.
    private var hasArchivedAccount: Bool {
        store?.accounts.contains { $0.type == .checking && $0.archived } ?? false
    }

    private func accountsSubtitle(store: AccountStore, visibleCount: Int) -> String {
        let totalCount = store.accounts.filter { $0.type == .checking }.count
        if hasArchivedAccount {
            return showArchived
                ? "\(visibleCount) de \(totalCount) contas visíveis"
                : "\(visibleCount) contas ativas"
        }
        return "\(visibleCount) \(visibleCount == 1 ? "conta" : "contas")"
    }

    /// Limpa seleção quando a conta selecionada some da lista visível
    /// (apagada, arquivada com toggle desligado, etc.). Diferente da
    /// `CreditCardsView`, não auto-seleciona o primeiro — em grid, seleção
    /// é sempre opt-in via clique do usuário.
    private func reconcileSelection(visibleIds: [UUID]) {
        guard let current = selectedAccountId, !visibleIds.contains(current) else { return }
        selectedAccountId = nil
    }

    private var emptyState: some View {
        EmptyStateView(
            "Sem contas por aqui",
            icon: .sidebarAccounts,
            description: "Cadastre as contas correntes que você usa (Inter, Nubank, XP, etc.) pra vincular transações e organizar suas movimentações."
        ) {
            Button {
                formMode = .create
            } label: {
                Label("Cadastrar primeira conta", systemImage: AppIcon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(formMode != nil)
        }
    }

    private func visible(store: AccountStore) -> [Account] {
        store.accounts.filter { account in
            guard account.type == .checking else { return false }
            return showArchived ? true : !account.archived
        }
    }

    private func editingAccount(from mode: FormMode) -> Account? {
        if case let .edit(account) = mode { return account }
        return nil
    }
}

// MARK: - Card

private struct AccountCard: View {
    let account: Account
    let displayName: String
    let institution: Institution?
    let currentBalance: Decimal
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggleArchive: () -> Void
    let onRequestDelete: () -> Void

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            Rectangle()
                .fill(accentColor)
                .frame(height: 4)

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                HStack(alignment: .top) {
                    accountIcon
                    Spacer()
                }

                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    HStack(spacing: GranaTheme.Spacing.xs) {
                        Text(displayName)
                            .font(GranaTheme.Typography.headline)
                        if account.archived {
                            Text("arquivada")
                                .font(GranaTheme.Typography.caption1)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, GranaTheme.Spacing.xs)
                                .padding(.vertical, GranaTheme.Spacing.xxs)
                                .background(
                                    Capsule().fill(Color.secondary.opacity(0.15))
                                )
                        }
                    }
                    Text("SALDO ATUAL")
                        .font(GranaTheme.Typography.caption2)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                }

                Text(currentBalance.formatted(.currency(code: account.currency)))
                    .font(GranaTheme.Typography.moneyTitle3)
                    .foregroundStyle(balanceColor)
            }
            .padding(GranaTheme.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .opacity(account.archived ? 0.6 : 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        // Context menu duplica as ações da toolbar pra acesso rápido por
        // right-click — sem precisar selecionar primeiro. Apagar passa por
        // `onRequestDelete` que seleciona a conta e abre o confirm a nível
        // de tela.
        .contextMenu {
            Button("Editar", action: onEdit)
            Button(account.archived ? "Desarquivar" : "Arquivar", action: onToggleArchive)
            Divider()
            Button("Apagar", role: .destructive, action: onRequestDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accentColor: Color {
        institution?.kind.brandColor ?? defaultAccent
    }

    private var defaultAccent: Color {
        switch account.type {
        case .creditCard: return .transfer
        default: return .accentColor
        }
    }

    /// Ícone da conta. Quando tem `Institution`, usa o avatar da marca
    /// (`InstitutionIcon`). Sem instituição (caso degenerado pós-Fase 4.5),
    /// cai num SF Symbol por tipo de conta sobre o tint do `accentColor`.
    @ViewBuilder
    private var accountIcon: some View {
        if let institution {
            InstitutionIcon(kind: institution.kind, size: 44)
        } else {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                Image(systemName: fallbackIconName)
                    .font(.system(size: GranaTheme.IconSize.medium))
                    .foregroundStyle(accentColor)
            }
            .frame(width: 44, height: 44)
        }
    }

    private var fallbackIconName: String {
        switch account.type {
        case .checking: return "building.columns"
        case .creditCard: return "creditcard.fill"
        }
    }

    private var balanceColor: Color {
        if account.archived { return .secondary }
        if currentBalance < 0 { return .danger }
        return .primary
    }
}
