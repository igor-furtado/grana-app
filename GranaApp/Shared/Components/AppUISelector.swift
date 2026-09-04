import SwiftUI

public struct SelectorOption<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: String
    public var badge: String?

    public init(id: ID, title: String, badge: String? = nil) {
        self.id = id
        self.title = title
        self.badge = badge
    }
}

public struct Selector<ID: Hashable>: View {
    public enum Style {
        case menu
        case segmented
    }

    private let label: String?
    private let placeholder: String
    private let options: [SelectorOption<ID>]
    private let includesNoneOption: Bool
    private let noneOptionTitle: String
    private let icon: String
    private let style: Style
    private let errorMessage: String?
    private let selectedID: () -> ID?
    private let setSelectedID: (ID?) -> Void

    public init(
        label: String? = nil,
        placeholder: String = "Selecione…",
        options: [SelectorOption<ID>],
        selection: Binding<ID?>,
        includesNoneOption: Bool = false,
        noneOptionTitle: String = "Nenhum",
        icon: String = "tag",
        style: Style = .menu,
        errorMessage: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self.options = options
        self.includesNoneOption = includesNoneOption
        self.noneOptionTitle = noneOptionTitle
        self.icon = icon
        self.style = style
        self.errorMessage = errorMessage
        self.selectedID = { selection.wrappedValue }
        self.setSelectedID = { selection.wrappedValue = $0 }
    }

    public init(
        label: String? = nil,
        options: [SelectorOption<ID>],
        selection: Binding<ID>,
        icon: String = "tag",
        style: Style = .menu,
        errorMessage: String? = nil
    ) {
        self.label = label
        self.placeholder = ""
        self.options = options
        self.includesNoneOption = false
        self.noneOptionTitle = "Nenhum"
        self.icon = icon
        self.style = style
        self.errorMessage = errorMessage
        self.selectedID = { selection.wrappedValue }
        self.setSelectedID = { newValue in
            guard let newValue else { return }
            selection.wrappedValue = newValue
        }
    }

    public var body: some View {
        switch style {
        case .menu:
            MenuField(
                label: label,
                icon: icon,
                errorMessage: errorMessage,
                options: allOptions,
                selectedTitle: selectedTitle,
                selectedBadge: selectedBadge,
                isEmpty: allOptions.isEmpty,
                emptyTitle: emptyTitle,
                setSelectedID: setSelectedID
            )
        case .segmented:
            Field(
                label: label,
                errorMessage: errorMessage
            ) {
                segmentedSelector
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var segmentedSelector: some View {
        SwiftUI.Picker("", selection: segmentedSelection) {
            ForEach(options) { option in
                Text(option.title).tag(Optional.some(option.id))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var segmentedSelection: Binding<ID?> {
        Binding(
            get: { selectedID() },
            set: { setSelectedID($0) }
        )
    }

    private var allOptions: [SelectorOption<ID?>] {
        var items: [SelectorOption<ID?>] = []
        if includesNoneOption {
            items.append(.init(id: nil, title: noneOptionTitle, badge: nil))
        }
        items.append(contentsOf: options.map { .init(id: Optional($0.id), title: $0.title, badge: $0.badge) })
        return items
    }

    private var selectedTitle: String {
        allOptions.first(where: { $0.id == selectedID() })?.title
            ?? normalizedPlaceholder
            ?? noneOptionTitle
    }

    private var selectedBadge: String? {
        allOptions.first(where: { $0.id == selectedID() })?.badge
    }

    private var normalizedPlaceholder: String? {
        placeholder.nilIfBlank
    }

    private var emptyTitle: String {
        "Nenhuma opção disponível"
    }
}

private struct MenuField<ID: Hashable>: View {
    let label: String?
    let icon: String
    let errorMessage: String?
    let options: [SelectorOption<ID?>]
    let selectedTitle: String
    let selectedBadge: String?
    let isEmpty: Bool
    let emptyTitle: String
    let setSelectedID: (ID?) -> Void

    var body: some View {
        Menu {
            if isEmpty {
                Button(emptyTitle) {}
                    .disabled(true)
            } else {
                ForEach(options) { option in
                    Button(option.title) {
                        setSelectedID(option.id)
                    }
                }
            }
        } label: {
            Field(
                label: label,
                leadingSystemImage: icon,
                errorMessage: errorMessage
            ) {
                valueLabel
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var valueLabel: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                Text(isEmpty ? emptyTitle : selectedTitle)
                    .font(Theme.Typography.body)
                    .foregroundStyle(isEmpty ? Theme.Palette.muted : Theme.Palette.ink)
                    .lineLimit(1)
            }

            if let badge = selectedBadge, !isEmpty {
                Text(badge)
                    .font(Theme.Typography.caption2Emphasis)
                    .foregroundStyle(Theme.Palette.tealDeep)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(
                        Theme.Palette.teal.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                    )
            }

            Image(systemName: "chevron.down")
                .font(.system(size: Theme.IconSize.micro, weight: .semibold))
                .foregroundStyle(Theme.Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct SelectorPreview: View {
    @State private var selectedCategory: String? = "alimentacao"
    @State private var selectedScope = "mes"

    private let categoryOptions = [
        SelectorOption(id: "alimentacao", title: "Alimentação", badge: "42"),
        SelectorOption(id: "moradia", title: "Moradia", badge: "8"),
        SelectorOption(id: "lazer", title: "Lazer", badge: "13"),
    ]

    private let scopeOptions = [
        SelectorOption(id: "semana", title: "Semana"),
        SelectorOption(id: "mes", title: "Mês"),
        SelectorOption(id: "ano", title: "Ano"),
    ]

    var body: some View {
        AppUIPreviewSurface(title: "Selector") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Selector(
                    label: "Categoria",
                    placeholder: "Selecione uma categoria",
                    options: categoryOptions,
                    selection: $selectedCategory,
                    includesNoneOption: true,
                    icon: Icon.sidebarCategories.systemImage
                )

                Selector(
                    label: "Período",
                    options: scopeOptions,
                    selection: $selectedScope,
                    style: .segmented
                )
            }
        }
    }
}

#Preview("AppUI.Selector") {
    SelectorPreview()
}
