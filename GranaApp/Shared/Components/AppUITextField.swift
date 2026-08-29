import SwiftUI

extension AppUI {
    struct TextField: View {
        private let label: String
        @Binding private var text: String
        private let placeholder: String?
        private let errorMessage: String?
        private let leadingSystemImage: String?
        private let showsClearButton: Bool
        private let font: Font

        init(
            label: String,
            text: Binding<String>,
            placeholder: String? = nil,
            errorMessage: String? = nil,
            leadingSystemImage: String? = nil,
            showsClearButton: Bool = false,
            font: Font = GranaTheme.Typography.body
        ) {
            self.label = label
            _text = text
            self.placeholder = placeholder
            self.errorMessage = errorMessage
            self.leadingSystemImage = leadingSystemImage
            self.showsClearButton = showsClearButton
            self.font = font
        }

        var body: some View {
            AppUI.Field(
                label: label,
                leadingSystemImage: leadingSystemImage,
                errorMessage: errorMessage,
            ) {
                HStack(spacing: GranaTheme.Spacing.sm) {
                    SwiftUI.TextField(
                        "",
                        text: $text,
                        prompt: normalizedPlaceholder.map {
                            SwiftUI.Text($0).foregroundStyle(GranaTheme.Palette.muted)
                        }
                    )
                    .textFieldStyle(.plain)
                    .font(font)
                    .multilineTextAlignment(.trailing)

                    if showsClearButton, !text.isEmpty {
                        clearButton
                    }
                }
            }
        }

        private var normalizedPlaceholder: String? {
            placeholder?.nilIfBlank
        }

        private var clearButton: some View {
            Button {
                text = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
            .buttonStyle(.plain)
        }
    }
}
