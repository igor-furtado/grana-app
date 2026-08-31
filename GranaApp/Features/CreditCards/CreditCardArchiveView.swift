import ComposableArchitecture
import SwiftUI

struct CreditCardArchiveView: View {
    @Bindable var store: StoreOf<CreditCardArchiveFeature>

    var body: some View {
        ZStack {
            GranaBackground()

            AppUI.Form.Shell {
                AppUI.Form.Header(
                    title: store.title,
                    subtitle: store.message
                )
                
                Spacer(minLength: GranaTheme.Spacing.none)

                if let saveError = store.saveError {
                    AppUI.Form.ErrorMessage(message: saveError)
                        .padding(.horizontal, GranaTheme.Spacing.lg)
                }

                AppUI.Form.Actions {
                    Button("Cancelar") {
                        store.send(.cancelButtonTapped)
                    }
                    .buttonStyle(GranaSecondaryButtonStyle())

                    Button(store.confirmTitle) {
                        store.send(.confirmButtonTapped)
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())
                    .disabled(store.isSaving)
                }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 460, idealWidth: 460, maxWidth: 460, minHeight: 240)
    }
}
