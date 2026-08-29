import SwiftUI

extension AppUI {
    struct DatePicker: View {
        enum Style {
            case compact
            case field
        }

        private let label: String
        @Binding private var selection: Date
        private let displayedComponents: DatePickerComponents
        private let errorMessage: String?
        private let isEnabled: Bool

        init(
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

        var body: some View {
             AppUI.Field(
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
}
