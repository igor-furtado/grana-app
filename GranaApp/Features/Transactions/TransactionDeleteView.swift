import ComposableArchitecture
import SwiftUI

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
                else {
                    Spacer(minLength: GranaTheme.Spacing.none)
                }

                if let saveError = store.saveError {
                    AppUI.Form.ErrorMessage(message: saveError)
                        .padding(.horizontal, GranaTheme.Spacing.lg)
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
        .frame(minWidth: 460, idealWidth: 460, maxWidth: 460, minHeight: 280)
    }

    private var messageBlock: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
            Image(systemName: AppIcon.warning.systemImage)
                .font(.system(size: GranaTheme.IconSize.small))
                .foregroundStyle(GranaTheme.Palette.amber)
                .padding(.top, GranaTheme.Spacing.xxs)

            Text(store.impactMessage)
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(GranaTheme.Spacing.lg)
    }

    private var transactionSummary: String {
        "\(store.transaction.description) - \(store.transaction.amount.formatted(.currency(code: "BRL")))"
    }
}
