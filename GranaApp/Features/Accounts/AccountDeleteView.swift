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
                    subtitle: "A conta só será apagada se não houver transações, faturas ou lotes de importação vinculados."
                )
                
                Spacer(minLength: AppUI.Theme.Spacing.none)

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
        .frame(minWidth: 460, idealWidth: 460, maxWidth: 460, minHeight: 240)
    }
}
