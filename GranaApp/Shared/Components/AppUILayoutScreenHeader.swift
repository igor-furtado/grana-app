import SwiftUI

public enum Layout {
    /// Header inline para telas principais que ocultam a window toolbar nativa.
    ///
    /// A estrutura segue a direção consolidada no protótipo validado: título e
    /// subtítulo à esquerda, com ações primárias alinhadas à direita.
    public struct ScreenHeader<Actions: View>: View {
        let title: String
        let subtitle: String?
        @ViewBuilder var actions: () -> Actions

        public init(
            title: String,
            subtitle: String? = nil,
            @ViewBuilder actions: @escaping () -> Actions
        ) {
            self.title = title
            self.subtitle = subtitle
            self.actions = actions
        }

        public init(
            title: String,
            subtitle: String? = nil
        ) where Actions == EmptyView {
            self.title = title
            self.subtitle = subtitle
            self.actions = { EmptyView() }
        }

        public var body: some View {
            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Theme.Spacing.sm) {
                    actions()
                }
                .frame(alignment: .trailing)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .granaSurface(.subtle, cornerRadius: Theme.Radius.card)
        }

        private var titleBlock: some View {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Palette.ink)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ScreenHeaderPreview: View {
    var body: some View {
        AppUIPreviewSurface(title: "Layout.ScreenHeader") {
            Layout.ScreenHeader(
                title: "Categorias",
                subtitle: "Header inline para telas autenticadas."
            ) {
                Button("Nova categoria") {}
                    .buttonStyle(GranaPrimaryButtonStyle())
                Button("Exportar") {}
                    .buttonStyle(GranaSecondaryButtonStyle())
            }
        }
    }
}

#Preview("AppUI.Layout.ScreenHeader") {
    ScreenHeaderPreview()
}
