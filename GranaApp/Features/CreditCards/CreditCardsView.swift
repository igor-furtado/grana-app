import ComposableArchitecture
import SwiftUI
import AppUI

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
                if store.list.visibleItems.isEmpty, !store.isLoading {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let statementsStore = store.scope(state: \.statements, action: \.statements) {
                    VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
                        CreditCardListView(store: store.scope(state: \.list, action: \.list))
                        CreditCardStatementsView(store: statementsStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    placeholderDetail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            "Sem cartões por aqui",
            icon: .sidebarCreditCards,
            description: "Cadastre os cartões de crédito que você usa pra acompanhar as faturas, fechamento, vencimento e limite."
        ) {
            Button {
                store.send(.list(.addButtonTapped))
            } label: {
                Label("Cadastrar primeiro cartão", systemImage: AppUI.Icon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
        }
    }

    private var placeholderDetail: some View {
        VStack(spacing: AppUI.Theme.Spacing.sm) {
            ProgressView()
            Text("Carregando cartões…")
                .font(AppUI.Theme.Typography.callout)
                .foregroundStyle(AppUI.Theme.Palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppUI.Theme.Spacing.xxxl)
        .granaSurface(.subtle, cornerRadius: AppUI.Theme.Radius.hero)
    }
}
