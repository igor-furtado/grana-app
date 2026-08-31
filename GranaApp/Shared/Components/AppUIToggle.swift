import SwiftUI

public struct Toggle: View {
    private let label: String?
    private let errorMessage: String?
    @Binding private var isOn: Bool

    public init(
        label: String? = nil,
        isOn: Binding<Bool>,
        errorMessage: String? = nil
    ) {
        _isOn = isOn
        self.label = label
        self.errorMessage = errorMessage
    }

    public var body: some View {
        if usesFieldShell {
            Field(label: normalizedLabel, errorMessage: normalizedErrorMessage) {
                toggleControl
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            toggleControl
        }
    }

    private var usesFieldShell: Bool {
        normalizedLabel != nil || normalizedErrorMessage != nil
    }

    private var normalizedLabel: String? {
        label?.nilIfBlank
    }

    private var normalizedErrorMessage: String? {
        errorMessage?.nilIfBlank
    }

    @ViewBuilder
    private var toggleControl: some View {
        if let normalizedLabel {
            SwiftUI.Toggle(normalizedLabel, isOn: $isOn)
        } else {
            SwiftUI.Toggle(isOn: $isOn) {
                EmptyView()
            }
        }
    }
}
