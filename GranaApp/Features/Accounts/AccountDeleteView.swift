import ComposableArchitecture
import SwiftUI

struct AccountDeleteView: View {
    @Bindable var store: StoreOf<AccountDeleteFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
            Text("Apagar conta")
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)

            Text("A conta só será apagada se não houver transações, faturas ou lotes de importação vinculados.")
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
