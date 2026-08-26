import Foundation
import SwiftUI

struct CreditCardsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: AccountStore?
    @State private var selectedCardId: UUID?
    @State private var formMode: FormMode?
    @State private var showArchived = false
    @State private var showDeleteConfirm = false

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
        let visibleCards = visible(store: store)
        return VStack(spacing: GranaTheme.Spacing.sm) {
            header(store: store, visibleCount: visibleCards.count)

            Group {
                if visibleCards.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    splitContent(store: store, cards: visibleCards)
                }
            }
        }
        .granaPagePadding()
        .sheet(item: $formMode) { mode in
            AccountFormView(
                existing: editingAccount(from: mode),
                lockedType: .creditCard,
                onCancel: { formMode = nil },
                onSaved: { formMode = nil }
            )
            .environment(store)
        }
        .confirmationDialog(
            "Apagar cartão?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Apagar", role: .destructive) {
                guard let id = selectedCardId else { return }
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
                "O cartão só será apagado se não houver transações, faturas ou lotes de importação vinculados."
            )
        }
        .onChange(of: visibleCards.map(\.id)) { _, ids in
            reconcileSelection(visibleIds: ids)
        }
        .onAppear {
            reconcileSelection(visibleIds: visibleCards.map(\.id))
        }
    }

    private func header(store: AccountStore, visibleCount: Int) -> some View {
        FeatureScreenHeader(
            title: "Cartões de crédito",
            subtitle: cardsSubtitle(store: store, visibleCount: visibleCount)
        ) {
            Button {
                formMode = .create
            } label: {
                Label("Novo cartão", systemImage: AppIcon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())

            if hasArchivedCard {
                Menu {
                    Toggle("Mostrar arquivados", isOn: $showArchived)
                } label: {
                    Label("Mais", systemImage: AppIcon.more.systemImage)
                }
                .buttonStyle(GranaSecondaryButtonStyle())
            }
        }
    }

    private func splitContent(store: AccountStore, cards: [Account]) -> some View {
        // `HSplitView` em vez de aninhar outro `NavigationSplitView`: o
        // pai (`ContentView`) já é split — aninhar deixa o macOS confuso
        // quanto a qual sidebar dobra. `HSplitView` é o controle nativo
        // pra split intra-feature, com divisor arrastável herdado do AppKit.
        HSplitView {
            CreditCardsSidebar(
                store: store,
                cards: cards,
                selectedId: $selectedCardId,
                onEdit: { account in
                    selectedCardId = account.id
                    formMode = .edit(account)
                },
                onToggleArchive: { account in
                    selectedCardId = account.id
                    Task {
                        do {
                            try await store.setArchived(account, archived: !account.archived)
                        } catch {
                            NoticeCenter.shared.report(error)
                        }
                    }
                },
                onRequestDelete: { account in
                    selectedCardId = account.id
                    showDeleteConfirm = true
                }
            )
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)

            if let selectedId = selectedCardId,
               let account = cards.first(where: { $0.id == selectedId })
            {
                CreditCardDetailView(account: account, store: store)
                    .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Fallback enquanto a seleção ainda não foi reconciliada
                // (primeira renderização ou cartão único acabou de ser
                // removido). Mostra placeholder em vez de detalhe quebrado.
                placeholderDetail
                    .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var placeholderDetail: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            Image(systemName: "creditcard")
                .font(.system(size: GranaTheme.IconSize.large))
                .foregroundStyle(.secondary)
            Text("Selecione um cartão")
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var hasArchivedCard: Bool {
        store?.accounts.contains { $0.type == .creditCard && $0.archived } ?? false
    }

    private func cardsSubtitle(store: AccountStore, visibleCount: Int) -> String {
        let totalCount = store.accounts.filter { $0.type == .creditCard }.count
        if hasArchivedCard {
            return showArchived
                ? "\(visibleCount) de \(totalCount) cartões visíveis"
                : "\(visibleCount) cartões ativos"
        }
        return "\(visibleCount) \(visibleCount == 1 ? "cartão" : "cartões")"
    }

    /// Reconcilia a seleção quando a lista de cartões visíveis muda: se a
    /// seleção atual sumiu (foi arquivada / deletada / o toggle de
    /// arquivados desligou), seleciona o primeiro disponível. Se nada
    /// está selecionado e há cartões, seleciona o primeiro.
    private func reconcileSelection(visibleIds: [UUID]) {
        if let current = selectedCardId, visibleIds.contains(current) { return }
        selectedCardId = visibleIds.first
    }

    private var emptyState: some View {
        EmptyStateView(
            "Sem cartões por aqui",
            icon: .sidebarCreditCards,
            description: "Cadastre os cartões de crédito que você usa pra acompanhar as faturas — dia de fechamento, vencimento e limite (opcional)."
        ) {
            Button {
                formMode = .create
            } label: {
                Label("Cadastrar primeiro cartão", systemImage: AppIcon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(formMode != nil)
        }
    }

    private func visible(store: AccountStore) -> [Account] {
        store.accounts.filter { account in
            guard account.type == .creditCard else { return false }
            return showArchived ? true : !account.archived
        }
    }

    private func editingAccount(from mode: FormMode) -> Account? {
        if case let .edit(account) = mode { return account }
        return nil
    }
}
