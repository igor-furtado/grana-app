import SwiftUI

public struct Field<TrailingContent: View>: View {
    private let label: String?
    private let leadingIcon: Icon?
    private let errorMessage: String?
    private let minHeight: CGFloat
    private let trailing: () -> TrailingContent

    public init(
        label: String? = nil,
        leadingIcon: Icon? = nil,
        errorMessage: String? = nil,
        minHeight: CGFloat = 40,
        @ViewBuilder trailing: @escaping () -> TrailingContent
    ) {
        self.label = label
        self.leadingIcon = leadingIcon
        self.errorMessage = errorMessage
        self.minHeight = minHeight
        self.trailing = trailing
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(alignment: .center, spacing: Theme.Spacing.lg) {
                if let leadingIcon {
                    leadingIconView(leadingIcon)
                }

                if let label = normalizedLabel {
                    Text(label)
                        .font(Theme.Typography.footnoteEmphasis)
                        .foregroundStyle(Theme.Palette.muted)
                        .frame(alignment: .leading)
                }

                trailing()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(controlBackground)

            if let errorMessage = normalizedErrorMessage {
                Text(errorMessage)
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(.danger)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    private var controlBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
            .fill(Theme.Palette.paper)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                    .stroke(Theme.Palette.line, lineWidth: 1)
            }
    }

    private var normalizedLabel: String? {
        label?.nilIfBlank
    }

    private var normalizedErrorMessage: String? {
        errorMessage?.nilIfBlank
    }

    private func leadingIconView(_ icon: Icon) -> some View {
        AppIcon(icon, size: Theme.IconSize.small, weight: .semibold)
            .foregroundStyle(Theme.Palette.tealDeep)
    }
}

extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

private struct FieldPreview: View {
    var body: some View {
        AppUIPreviewSurface(title: "Field") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Field(
                    leadingIcon: .sidebarInstitutions
                ) {
                    Text("Banco Inter")
                        .font(Theme.Typography.bodyEmphasis)
                        .foregroundStyle(Theme.Palette.ink)
                }

                Field(
                    leadingIcon: .edit,
                    errorMessage: "O campo não pode ficar vazio."
                ) {
                    Text("Compra do mês")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.muted)
                }
            }
        }
    }
}

#Preview("AppUI.Field") {
    FieldPreview()
}
