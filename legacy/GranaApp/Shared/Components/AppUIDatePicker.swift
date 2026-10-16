import SwiftUI

public struct DatePicker: View {
    public enum Style {
        case compact
        case field
    }

    private let label: String
    @Binding private var selection: Date
    private let displayedComponents: DatePickerComponents
    private let errorMessage: String?
    private let isEnabled: Bool

    public init(
        label: String,
        selection: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date],
        errorMessage: String? = nil,
        isEnabled: Bool = true
    ) {
        self.label = label
        _selection = selection
        self.displayedComponents = displayedComponents
        self.errorMessage = errorMessage
        self.isEnabled = isEnabled
    }

    public var body: some View {
        Field(
            label: label,
            errorMessage: errorMessage
        ) {
            SwiftUI.DatePicker(
                "",
                selection: $selection,
                displayedComponents: displayedComponents
            )
            .datePickerStyle(.compact)
            .disabled(!isEnabled)
        }
    }
}

private struct DatePickerPreview: View {
    @State private var invoiceDate = Date.now
    @State private var dueDate = Date.now.addingTimeInterval(86_400 * 5)

    var body: some View {
        AppUIPreviewSurface(title: "DatePicker") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                DatePicker(
                    label: "Fechamento",
                    selection: $invoiceDate
                )

                DatePicker(
                    label: "Vencimento",
                    selection: $dueDate,
                    errorMessage: "A data precisa ser posterior ao fechamento."
                )
            }
        }
    }
}

#Preview("AppUI.DatePicker") {
    DatePickerPreview()
}
