import SwiftUI

extension AppUI {
    struct Toggle: View {
        private let label: String?
        private let errorMessage: String?
        @Binding private var isOn: Bool

        init(
            label: String? = nil,
            isOn: Binding<Bool>,
            errorMessage: String? = nil
        ) {
            _isOn = isOn
            self.label = label
            self.errorMessage = errorMessage
        }

        var body: some View {
            Button {
                isOn.toggle()
            } label: {
                AppUI.Field(label: label, errorMessage: errorMessage) {
                    HStack(spacing: GranaTheme.Spacing.none) {
                        Spacer(minLength: GranaTheme.Spacing.none)

                        SwiftUI.Toggle("", isOn: $isOn)
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }
}
