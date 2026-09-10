import AppKit
import Foundation
import SwiftUI

public struct CurrencyField: View {
    private let label: String
    @Binding private var cents: Int
    private let currencyCode: String
    private let placeholder: String
    private let errorMessage: String?

    public init(
        label: String,
        cents: Binding<Int>,
        currencyCode: String = "BRL",
        placeholder: String = "R$ 0,00",
        errorMessage: String? = nil
    ) {
        self.label = label
        _cents = cents
        self.currencyCode = currencyCode
        self.placeholder = placeholder
        self.errorMessage = errorMessage
    }

    public var body: some View {
        Field(
            label: label,
            errorMessage: errorMessage
        ) {
            CurrencyTextField(cents: $cents, currencyCode: currencyCode, placeholder: placeholder)
                .font(Theme.Typography.moneyBody)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private enum AppUICurrencyFormat {
    static func format(_ cents: Int, currencyCode: String) -> String {
        let formatter = formatter(currencyCode: currencyCode)
        let decimal = Decimal(cents) / 100
        return formatter.string(from: decimal as NSDecimalNumber) ?? "\(currencyCode) 0.00"
    }

    private static func formatter(currencyCode: String) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = currencyCode == "BRL" ? Locale(identifier: "pt_BR") : Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

private struct CurrencyTextField: NSViewRepresentable {
    @Binding var cents: Int
    let currencyCode: String
    let placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.font = Theme.Typography.moneyBodyNSFont
        textField.alignment = .right
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.stringValue = AppUICurrencyFormat.format(cents, currencyCode: currencyCode)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.font = Theme.Typography.moneyBodyNSFont
        guard !context.coordinator.isEditing else { return }
        let expected = AppUICurrencyFormat.format(cents, currencyCode: currencyCode)
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
            let formatted = AppUICurrencyFormat.format(newCents, currencyCode: parent.currencyCode)

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

private struct CurrencyFieldPreview: View {
    @State private var cents = 249_990

    var body: some View {
        AppUIPreviewSurface(title: "CurrencyField") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                CurrencyField(label: "Limite disponível", cents: $cents)

                CurrencyField(
                    label: "Valor inválido",
                    cents: $cents,
                    errorMessage: "Revise o valor antes de continuar."
                )
            }
        }
    }
}

#Preview("AppUI.CurrencyField") {
    CurrencyFieldPreview()
}
