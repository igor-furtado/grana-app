import AppUI
import ComposableArchitecture
import SwiftUI

struct AccountsView: View {
    @Bindable var store: StoreOf<AccountsFeature>

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Layout.ScreenHeader(
                title: "Contas",
                subtitle: store.list.summarySubtitle
            ) {
                Button {
                    store.send(.list(.addButtonTapped))
                } label: {
                    Label("Nova conta", systemImage: AppUI.Icon.add.systemImage)
                }
                .buttonStyle(GranaPrimaryButtonStyle())
            }

            Group {
                if store.isLoading {
                    AccountListSkeletonView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.list.items.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AccountListView(store: store.scope(state: \.list, action: \.list))
                }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).form
        ) { formStore in
            AccountFormView(store: formStore)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).archive
        ) { archiveStore in
            AccountArchiveView(store: archiveStore)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).delete
        ) { deleteStore in
            AccountDeleteView(store: deleteStore)
        }
        .task {
            await store.send(.task).finish()
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            "Sem contas por aqui",
            icon: .sidebarAccounts,
            description: "Cadastre as contas correntes que você usa (Inter, Nubank, XP, etc.) pra vincular transações e organizar suas movimentações."
        ) {
            Button {
                store.send(.list(.addButtonTapped))
            } label: {
                Label("Cadastrar primeira conta", systemImage: AppUI.Icon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
        }
    }
}
