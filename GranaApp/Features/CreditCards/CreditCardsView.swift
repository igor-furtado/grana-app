import AppUI
import ComposableArchitecture
import SwiftUI

struct CreditCardsView: View {
    @Bindable var store: StoreOf<CreditCardsFeature>

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Layout.ScreenHeader(
                title: "Cartões de crédito",
                subtitle: store.list.summarySubtitle
            ) {
                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    Button {
                        store.send(.list(.addButtonTapped))
                    } label: {
                        Label("Novo cartão", systemImage: AppUI.Icon.add.systemImage)
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())

                    if store.list.hasArchivedCard {
                        Menu {
                            AppUI.Toggle(
                                label: "Mostrar arquivados",
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
                    CreditCardsLoadingView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.list.items.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
                        CreditCardListView(store: store.scope(state: \.list, action: \.list))
                        if let statementsStore = store.scope(state: \.statements, action: \.statements) {
                            CreditCardStatementsView(store: statementsStore)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).form
        ) { formStore in
            CreditCardFormView(store: formStore)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).archive
        ) { archiveStore in
            CreditCardArchiveView(store: archiveStore)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).delete
        ) { deleteStore in
            CreditCardDeleteView(store: deleteStore)
        }
        .task {
            await store.send(.task).finish()
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            "Cadastre seu primeiro cartão",
            icon: .sidebarCreditCards,
            description: "Adicione os cartões de crédito que você usa no dia a dia"
        ) {
            Button {
                store.send(.list(.addButtonTapped))
            } label: {
                Label("Cadastrar primeiro cartão", systemImage: AppUI.Icon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
        }
    }
}
