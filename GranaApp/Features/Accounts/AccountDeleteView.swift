import ComposableArchitecture
import SwiftUI
import AppUI

struct AccountDeleteView: View {
    @Bindable var store: StoreOf<AccountDeleteFeature>

    var body: some View {
        ZStack {
            GranaBackground()

            AppUI.Form.Shell {
                AppUI.Form.Header(
                    title: "Apagar conta",
                    subtitle: "A conta só será apagada se não houver transações vinculadas."
                )
                
                if let saveError = store.saveError {
                    AppUI.Form.ErrorMessage(message: saveError)
                        .padding(.horizontal, AppUI.Theme.Spacing.lg)
                }
                
                AppUI.Form.Actions {
                    Button("Cancelar") {
                        store.send(.cancelButtonTapped)
                    }
                    .buttonStyle(GranaSecondaryButtonStyle())

                    Button("Apagar") {
                        store.send(.confirmButtonTapped)
                    }
                    .buttonStyle(GranaDestructiveButtonStyle())
                    .disabled(store.isSaving)
                }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(width: AppUI.Modal.SheetSize.compactWidth)
        .presentationSizing(.fitted)
    }
}
