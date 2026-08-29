import AppKit
import Foundation
import SwiftUI

extension AppUI {
    struct CurrencyField: View {
        private let label: String
        @Binding private var cents: Int
        private let placeholder: String
        private let errorMessage: String?

        init(
            label: String,
            cents: Binding<Int>,
            placeholder: String = "R$ 0,00",
            errorMessage: String? = nil
        ) {
            self.label = label
            _cents = cents
            self.placeholder = placeholder
            self.errorMessage = errorMessage
        }

        var body: some View {
            AppUI.Field(
                label: label,
                errorMessage: errorMessage
            ) {
                CurrencyTextField(cents: $cents, placeholder: placeholder)
                    .font(GranaTheme.Typography.moneyBody)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

/// Formatação reaproveitável para moeda BRL no input visual do app.
private enum AppUICurrencyFormat {
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func format(_ cents: Int) -> String {
        let decimal = Decimal(cents) / 100
        return formatter.string(from: decimal as NSDecimalNumber) ?? "R$ 0,00"
    }
}

private struct CurrencyTextField: NSViewRepresentable {
    @Binding var cents: Int
    let placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.font = GranaTheme.Typography.moneyBodyNSFont
        textField.alignment = .right
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.stringValue = AppUICurrencyFormat.format(cents)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.font = GranaTheme.Typography.moneyBodyNSFont
        guard !context.coordinator.isEditing else { return }
        let expected = AppUICurrencyFormat.format(cents)
        if nsView.stringValue != expected {
            nsView.stringValue = expected
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CurrencyTextField
        var isEditing = false

        init(parent: CurrencyTextField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            let digits = textField.stringValue.filter(\.isNumber)
            let newCents = Int(digits) ?? 0
            let formatted = AppUICurrencyFormat.format(newCents)

            if textField.stringValue != formatted {
                textField.stringValue = formatted

                if let editor = textField.currentEditor() {
                    let end = (formatted as NSString).length
                    editor.selectedRange = NSRange(location: end, length: 0)
                }
            }

            parent.cents = newCents
        }
    }
}
