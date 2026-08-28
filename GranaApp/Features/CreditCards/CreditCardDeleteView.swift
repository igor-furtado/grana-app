import ComposableArchitecture
import SwiftUI

struct CreditCardDeleteView: View {
    @Bindable var store: StoreOf<CreditCardDeleteFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
            Text("Apagar cartão")
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)

            Text("O cartão só será apagado se não houver transações, faturas ou lotes de importação vinculados.")
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)

            if let saveError = store.saveError {
                Text(saveError)
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(.danger)
            }

            BottomActionBar {
                Button("Cancelar") {
                    store.send(.cancelButtonTapped)
                }
                Button("Apagar") {
                    store.send(.confirmButtonTapped)
                }
                .buttonStyle(.borderedProminent)
                .tint(.danger)
                .disabled(store.isSaving)
            }
        }
        .padding(GranaTheme.Spacing.xl)
        .frame(minWidth: 460, idealWidth: 460)
    }
}
