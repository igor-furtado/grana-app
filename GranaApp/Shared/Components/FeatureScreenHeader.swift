import SwiftUI

/// Header inline para telas principais que ocultam a window toolbar nativa.
///
/// A estrutura segue a direção já usada em `TransactionsView`: bloco principal
/// com título/subtítulo e painel lateral para ações primárias.
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

    var body: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
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
            .padding(GranaTheme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.panel)

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                actions()
            }
            .frame(width: 288)
        }
    }
}
