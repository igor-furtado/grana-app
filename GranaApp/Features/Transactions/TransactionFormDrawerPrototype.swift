import SwiftUI

enum TransactionFormPrototypeTextStyle {
    case panel
}

enum TransactionFormPrototypeCategoryStyle {
    case filterMenu
}

typealias TransactionFormPrototypeOption<ID: Hashable> = AppUI.SelectorOption<ID>

enum TransactionFormPrototypeStatementItem: Identifiable {
    case empty(message: String)
    case filled(title: String, value: String)

    var id: String {
        switch self {
        case let .empty(message):
            "empty-\(message)"
        case let .filled(title, value):
            "filled-\(title)-\(value)"
        }
    }
}

@available(*, deprecated, renamed: "AppUI.Selector")
typealias TransactionFormPrototypeOptionSelector<ID: Hashable> = AppUI.Selector<ID>

struct TransactionFormPrototypeDateSelector: View {
    @Binding var selection: Date

    var body: some View {
        AppUI.DatePicker(
            label: "",
            selection: $selection,
            displayedComponents: [.date],
        )
    }
}

struct TransactionFormPrototypeTimeSelector: View {
    @Binding var selection: Date

    var body: some View {
        AppUI.DatePicker(
            label: "",
            selection: $selection,
            displayedComponents: [.hourAndMinute],
        )
    }
}

struct TransactionFormPrototypeNotesField: View {
    @Binding var text: String
    let style: TransactionFormPrototypeTextStyle

    var body: some View {
        switch style {
        case .panel:
            searchLikeNotes
        }
    }

    private var searchLikeNotes: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Observação, contexto, lembrete…")
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .padding(.horizontal, GranaTheme.Spacing.md)
                    .padding(.vertical, GranaTheme.Spacing.sm)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(GranaTheme.Typography.body)
                .foregroundStyle(GranaTheme.Palette.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .padding(GranaTheme.Spacing.xs)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GranaTheme.Palette.paper.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GranaTheme.Palette.line, lineWidth: 1)
                }
        )
    }
}

struct TransactionFormPrototypeStatementSummary: View {
    let items: [TransactionFormPrototypeStatementItem]

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            ForEach(items) { item in
                switch item {
                case let .empty(message):
                    Text(message)
                        .font(GranaTheme.Typography.callout)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(GranaTheme.Spacing.sm)
                        .background(rowBackground)
                case let .filled(title, value):
                    HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                        Text(title)
                            .font(GranaTheme.Typography.footnote)
                            .foregroundStyle(GranaTheme.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: GranaTheme.Spacing.none)
                        Text(value)
                            .font(GranaTheme.Typography.moneyFootnote)
                            .foregroundStyle(GranaTheme.Palette.ink)
                    }
                    .padding(GranaTheme.Spacing.sm)
                    .background(rowBackground)
                }
            }
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
            .fill(GranaTheme.Palette.paper)
    }
}
