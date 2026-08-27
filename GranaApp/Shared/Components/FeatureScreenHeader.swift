import SwiftUI

/// Header inline para telas principais que ocultam a window toolbar nativa.
///
/// A estrutura segue a direção consolidada no protótipo validado: título e
/// subtítulo à esquerda, com ações primárias alinhadas à direita.
struct FeatureScreenHeader<Actions: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var actions: () -> Actions

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
    }

    init(
        title: String,
        subtitle: String? = nil
    ) where Actions == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.actions = { EmptyView() }
    }

    var body: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.lg) {
            titleBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: GranaTheme.Spacing.sm) {
                actions()
            }
            .frame(alignment: .trailing)
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
            Text(title)
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(GranaTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
