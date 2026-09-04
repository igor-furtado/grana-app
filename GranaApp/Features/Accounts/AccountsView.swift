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
                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    Button {
                        store.send(.list(.addButtonTapped))
                    } label: {
                        Label("Nova conta", systemImage: AppUI.Icon.add.systemImage)
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())

                    if store.list.hasArchivedAccount {
                        Menu {
                            AppUI.Toggle(
                                label: "Mostrar arquivadas",
                                isOn: Binding(
                                    get: { store.list.showArchived },
                                    set: { store.send(.list(.binding(.set(\.showArchived, $0)))) }
                                )
                            )
                        } label: {
                            Label("Mais", systemImage: AppUI.Icon.more.systemImage)
                        }
                        .buttonStyle(GranaSecondaryButtonStyle())
                    }
                }
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
            "Cadastre sua primeira conta",
            icon: .sidebarAccounts,
            description: "Adicione as contas bancárias que você usa no dia a dia"
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
