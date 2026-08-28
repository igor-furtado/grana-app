import ComposableArchitecture
import SwiftUI

struct TransactionDeleteView: View {
    @Bindable var store: StoreOf<TransactionDeleteFeature>

    var body: some View {
        ZStack {
            GranaBackground()

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xl) {
                header
                if !store.impactMessage.isEmpty {
                    messageBlock
                }
                if let saveError = store.saveError {
                    Text(saveError)
                        .font(GranaTheme.Typography.callout)
                        .foregroundStyle(.danger)
                }
                Spacer(minLength: GranaTheme.Spacing.none)
                actions
            }
            .padding(GranaTheme.Spacing.xl)
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 460, idealWidth: 460, maxWidth: 460, minHeight: 280)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            HStack(spacing: GranaTheme.Spacing.sm) {
                Image(systemName: AppIcon.delete.systemImage)
                    .font(.system(size: GranaTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.red)

                Text("Apagar transação?")
                    .font(GranaTheme.Typography.title3)
                    .foregroundStyle(GranaTheme.Palette.ink)
            }

            Text(transactionSummary)
                .font(GranaTheme.Typography.bodyEmphasis)
                .foregroundStyle(GranaTheme.Palette.ink)
        }
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
        .padding(GranaTheme.Spacing.md)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
    }

    private var actions: some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            Spacer(minLength: GranaTheme.Spacing.none)

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

    private var transactionSummary: String {
        "\(store.transaction.description) - \(store.transaction.amount.formatted(.currency(code: "BRL")))"
    }
}
