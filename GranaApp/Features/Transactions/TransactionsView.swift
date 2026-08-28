import ComposableArchitecture
import SwiftUI

struct TransactionsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: StoreOf<TransactionsFeature>?
    private let showsDrawerOverlay: Bool

    init(store: StoreOf<TransactionsFeature>? = nil, showsDrawerOverlay: Bool = true) {
        _store = State(initialValue: store)
        self.showsDrawerOverlay = showsDrawerOverlay
    }

    var body: some View {
        ZStack {
            if let store {
                TransactionsLoadedView(store: store)
                    .environment(environment)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showsDrawerOverlay, let store {
                TransactionFormDrawerOverlay(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if store == nil {
                store = Store(initialState: TransactionsFeature.State()) {
                    TransactionsFeature()
                } withDependencies: {
                    $0.transactionsClient = .live(container: environment.container)
                }
            }
        }
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
