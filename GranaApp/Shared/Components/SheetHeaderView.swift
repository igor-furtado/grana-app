import SwiftUI

/// Header inline para sheets e modais que não usam toolbar nativa.
struct SheetHeaderView: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                Text(title)
                    .font(GranaTheme.Typography.title3)
                    .foregroundStyle(GranaTheme.Palette.ink)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(GranaTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GranaTheme.Spacing.lg)
            .padding(.top, GranaTheme.Spacing.lg)
            .padding(.bottom, GranaTheme.Spacing.md)

            Divider()
        }
    }
}
