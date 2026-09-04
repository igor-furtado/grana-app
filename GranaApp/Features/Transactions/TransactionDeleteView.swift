import ComposableArchitecture
import SwiftUI
import AppUI

struct TransactionDeleteView: View {
    @Bindable var store: StoreOf<TransactionDeleteFeature>

    var body: some View {
        ZStack {
            GranaBackground()

            AppUI.Form.Shell {
                AppUI.Form.Header(
                    title: "Apagar transação?",
                    subtitle: transactionSummary
                )
                                
                if !store.impactMessage.isEmpty {
                    messageBlock
                }

                if let saveError = store.saveError {
                    AppUI.Form.ErrorMessage(message: saveError)
                        .padding(.horizontal, AppUI.Theme.Spacing.lg)
                }
                
                AppUI.Form.Actions {
                    Button("Cancelar") {
                        store.send(.cancelButtonTapped)
                    }
                    .buttonStyle(GranaSecondaryButtonStyle())
                    .disabled(store.isSaving)

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

    private var messageBlock: some View {
        Text(store.impactMessage)
            .font(AppUI.Theme.Typography.callout)
            .foregroundStyle(AppUI.Theme.Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
        .padding(AppUI.Theme.Spacing.lg)
    }

    private var transactionSummary: String {
        "\(store.transaction.description) - \(store.transaction.amount.formatted(.currency(code: "BRL")))"
    }
}
