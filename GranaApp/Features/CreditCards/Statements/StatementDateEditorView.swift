import ComposableArchitecture
import Foundation
import SwiftUI

struct StatementDateEditorView: View {
    @Bindable var store: StoreOf<StatementDateEditorFeature>

    var body: some View {
        ZStack {
            GranaBackground()

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xl) {
                header
                dateFields
                explanatoryText
                Spacer(minLength: GranaTheme.Spacing.none)
                actions
            }
            .padding(GranaTheme.Spacing.xl)
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 520, idealWidth: 520, maxWidth: 520, minHeight: 320)
        .environment(\.timeZone, TimeZone(secondsFromGMT: 0) ?? .current)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
            Text(store.title)
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)

            Text("Datas próprias desta fatura")
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)
        }
    }

    private var dateFields: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            dateRow("Data de fechamento", selection: $store.closingDate)

            Divider()
                .overlay(GranaTheme.Palette.line)

            dateRow("Data de vencimento", selection: $store.dueDate)
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
    }

    private var explanatoryText: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
            Image(systemName: AppIcon.info.systemImage)
                .font(.system(size: GranaTheme.IconSize.small))
                .foregroundStyle(GranaTheme.Palette.amber)
                .padding(.top, GranaTheme.Spacing.xxs)

            Text(
                "Alterar o fechamento realoca compras e créditos entre faturas. Pagamentos permanecem na fatura onde foram registrados."
            )
            .font(GranaTheme.Typography.callout)
            .foregroundStyle(GranaTheme.Palette.muted)
        }
    }

    private var actions: some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            Spacer(minLength: GranaTheme.Spacing.none)

            Button("Cancelar") {
                store.send(.cancelButtonTapped)
            }
            .buttonStyle(GranaSecondaryButtonStyle())
            .disabled(store.isSaving)

            Button {
                store.send(.saveButtonTapped)
            } label: {
                if store.isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 88)
                } else {
                    Text("Salvar datas")
                        .frame(minWidth: 88)
                }
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(store.isSaving)
        }
    }

    private func dateRow(_ title: String, selection: Binding<Date>) -> some View {
        HStack(spacing: GranaTheme.Spacing.md) {
            Text(title)
                .font(GranaTheme.Typography.bodyEmphasis)
                .foregroundStyle(GranaTheme.Palette.ink)

            Spacer(minLength: GranaTheme.Spacing.md)

            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .disabled(store.isSaving)
        }
        .padding(.vertical, GranaTheme.Spacing.md)
    }
}
