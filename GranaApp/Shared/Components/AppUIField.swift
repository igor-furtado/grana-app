import SwiftUI

public struct Field<TrailingContent: View>: View {
    private let label: String?
    private let leadingSystemImage: String?
    private let errorMessage: String?
    private let minHeight: CGFloat
    private let trailing: () -> TrailingContent

    public init(
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

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(alignment: .center, spacing: Theme.Spacing.lg) {
                if let leadingSystemImage {
                    leadingIcon(systemName: leadingSystemImage)
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

    private func leadingIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: Theme.IconSize.small, weight: .semibold))
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
                    label: "Instituição",
                    leadingSystemImage: Icon.sidebarInstitutions.systemImage
                ) {
                    Text("Banco Inter")
                        .font(Theme.Typography.bodyEmphasis)
                        .foregroundStyle(Theme.Palette.ink)
                }

                Field(
                    label: "Descrição",
                    leadingSystemImage: Icon.edit.systemImage,
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
