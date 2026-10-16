import AppUI
import ComposableArchitecture
import SwiftUI

struct TransactionsView: View {
    @Bindable var store: StoreOf<TransactionsFeature>
    @Environment(\.calendar) private var calendar

    var body: some View {

        VStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Layout.ScreenHeader(
                title: "Transações",
                subtitle: store.list.transactionsCountText(calendar: calendar)
            ) {
                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    Button {
                        store.send(.list(.addButtonTapped)) 
                    } label: {
                        Label("Nova transação", systemImage: AppUI.Icon.add.systemImage)
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())
                }
            }

            Group {
                if store.isLoading {
                    TransactionsSkeletonView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TransactionListView(store: store.scope(state: \.list, action: \.list))
                }
            }
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).editForm
        ) { formStore in
            TransactionFormView(store: formStore)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).delete
        ) { deleteStore in
            TransactionDeleteView(store: deleteStore)
        }
        .task {
            await store.send(.task).finish()
        }            
    }
}
