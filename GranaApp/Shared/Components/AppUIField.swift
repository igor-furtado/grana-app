import SwiftUI

extension AppUI {
    struct Field<TrailingContent: View>: View {
        private let label: String?
        private let leadingSystemImage: String?
        private let errorMessage: String?
        private let minHeight: CGFloat
        private let trailing: () -> TrailingContent

        init(
            label: String? = nil,
            leadingSystemImage: String? = nil,
            errorMessage: String? = nil,
            minHeight: CGFloat = 40,
            @ViewBuilder trailing: @escaping () -> TrailingContent
        ) {
            self.label = label
            self.leadingSystemImage = leadingSystemImage
            self.errorMessage = errorMessage
            self.minHeight = minHeight
            self.trailing = trailing
        }

        var body: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                HStack(alignment: .center, spacing: GranaTheme.Spacing.lg) {
                    if let leadingSystemImage {
                        leadingIcon(systemName: leadingSystemImage)
                    }

                    if let label = normalizedLabel {
                        Text(label)
                            .font(GranaTheme.Typography.footnoteEmphasis)
                            .foregroundStyle(GranaTheme.Palette.muted)
                            .frame(alignment: .leading)
                    }

                    trailing()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, GranaTheme.Spacing.lg)
                .padding(.vertical, GranaTheme.Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
                .background(controlBackground)

                if let errorMessage = normalizedErrorMessage {
                    Text(errorMessage)
                        .font(GranaTheme.Typography.caption2)
                        .foregroundStyle(.danger)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, GranaTheme.Spacing.lg)
                }
            }
        }

        private var controlBackground: some View {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.pill, style: .continuous)
                .fill(GranaTheme.Palette.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: GranaTheme.Radius.pill, style: .continuous)
                        .stroke(GranaTheme.Palette.line, lineWidth: 1)
                }
        }

        private var normalizedLabel: String? {
            label?.nilIfBlank
        }

        private var normalizedErrorMessage: String? {
            errorMessage?.nilIfBlank
        }

        private func leadingIcon(systemName: String) -> some View {
            Image(systemName: systemName)
                .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(GranaTheme.Palette.tealDeep)
        }
    }
}

extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
