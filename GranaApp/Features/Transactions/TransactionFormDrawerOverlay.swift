import ComposableArchitecture
import SwiftUI

struct TransactionFormDrawerOverlay: View {
    @Bindable var store: StoreOf<TransactionsFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let formStore = $store.scope(\.destination, action: \.destination).editForm.wrappedValue {
                SideDrawer(
                    onDismiss: {
                        formStore.send(.cancelButtonTapped)
                    },
                    content: {
                        TransactionFormView(store: formStore)
                    }
                )
                .transition(drawerTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(drawerAnimation, value: store.destination != nil)
    }

    private var drawerTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }

    private var drawerAnimation: Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.35, bounce: 0.12)
    }
}
