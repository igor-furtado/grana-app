import ComposableArchitecture
import SwiftUI

struct AccountArchiveView: View {
    @Bindable var store: StoreOf<AccountArchiveFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
            Text(store.title)
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)

            Text(store.message)
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
                Button(store.confirmTitle) {
                    store.send(.confirmButtonTapped)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSaving)
            }
        }
        .padding(GranaTheme.Spacing.xl)
        .frame(minWidth: 460, idealWidth: 460)
    }
}
