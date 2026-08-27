import SwiftUI

/// Header inline para telas principais que ocultam a window toolbar nativa.
///
/// A estrutura segue a direção consolidada no protótipo validado: prateleira
/// lateral com título/ações e, opcionalmente, uma coluna operacional à direita
/// para busca, filtros ou outros controles da tela.
struct FeatureScreenHeader<Operations: View, Actions: View>: View {
    let title: String
    let subtitle: String?
    private let hasOperations: Bool
    @ViewBuilder var operations: () -> Operations
    @ViewBuilder var actions: () -> Actions

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder operations: @escaping () -> Operations,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.hasOperations = true
        self.operations = operations
        self.actions = actions
    }

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) where Operations == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.hasOperations = false
        self.operations = { EmptyView() }
        self.actions = actions
    }

    var body: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                titleBlock
                actions()
            }
            .frame(maxWidth: hasOperations ? 360 : .infinity, alignment: .leading)

            if hasOperations {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                    operations()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
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
