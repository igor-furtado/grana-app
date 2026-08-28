import SwiftUI

enum TransactionFormPrototypeTextStyle {
    case panel
}

enum TransactionFormPrototypeCategoryStyle {
    case filterMenu
}

struct TransactionFormPrototypeOption<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    var badge: String?
}

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

struct TransactionFormPrototypeOptionSelector<ID: Hashable>: View {
    let title: String
    let subtitle: String?
    let options: [TransactionFormPrototypeOption<ID>]
    @Binding var selection: ID?
    var includesNoneOption = false
    var noneOptionTitle = "Nenhum"
    var style: TransactionFormPrototypeCategoryStyle = .filterMenu
    var icon: String = "tag"

    var body: some View {
        switch style {
        case .filterMenu:
            filterMenu
        }
    }

    private var allOptions: [TransactionFormPrototypeOption<ID?>] {
        var items: [TransactionFormPrototypeOption<ID?>] = []
        if includesNoneOption {
            items.append(.init(id: nil, title: noneOptionTitle, badge: nil))
        }
        items.append(contentsOf: options.map { .init(id: Optional($0.id), title: $0.title, badge: $0.badge) })
        return items
    }

    private var selectedTitle: String {
        allOptions.first(where: { $0.id == selection })?.title ?? noneOptionTitle
    }

    private var filterMenu: some View {
        Menu {
            ForEach(allOptions) { option in
                Button(option.title) {
                    selection = option.id
                }
            }
        } label: {
            HStack(spacing: GranaTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.tealDeep)

                Text(selectedTitle)
                    .font(GranaTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(GranaTheme.Palette.ink)
                    .lineLimit(1)

                Spacer(minLength: GranaTheme.Spacing.none)

                Image(systemName: "chevron.down")
                    .font(.system(size: GranaTheme.IconSize.micro, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
            .padding(.horizontal, GranaTheme.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GranaTheme.Palette.paper.opacity(0.92))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GranaTheme.Palette.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct TransactionFormPrototypeDateSelector: View {
    @Binding var selection: Date

    var body: some View {
        DatePicker("", selection: $selection, displayedComponents: [.date])
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(.horizontal, GranaTheme.Spacing.md)
            .padding(.vertical, GranaTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(controlBackground)
    }

    private var controlBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(GranaTheme.Palette.paper)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GranaTheme.Palette.line, lineWidth: 1)
            }
    }
}

struct TransactionFormPrototypeTimeSelector: View {
    @Binding var selection: Date

    var body: some View {
        DatePicker("", selection: $selection, displayedComponents: [.hourAndMinute])
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(.horizontal, GranaTheme.Spacing.md)
            .padding(.vertical, GranaTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(controlBackground)
    }

    private var controlBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(GranaTheme.Palette.paper)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GranaTheme.Palette.line, lineWidth: 1)
            }
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
