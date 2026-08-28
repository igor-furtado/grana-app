import ComposableArchitecture
import SwiftUI

struct TransactionsView: View {
    @Bindable var store: StoreOf<TransactionsFeature>
    private let showsDrawerOverlay: Bool

    init(store: StoreOf<TransactionsFeature>, showsDrawerOverlay: Bool = true) {
        self.store = store
        self.showsDrawerOverlay = showsDrawerOverlay
    }

    var body: some View {
        ZStack {
            TransactionsLoadedView(store: store)

            if showsDrawerOverlay {
                TransactionFormDrawerOverlay(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TransactionsLoadedView: View {
    @Bindable var store: StoreOf<TransactionsFeature>

    var body: some View {
        TransactionListView(store: store.scope(state: \.list, action: \.list))
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
