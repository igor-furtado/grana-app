import SwiftUI

extension AppUI {
    struct SelectorOption<ID: Hashable>: Identifiable {
        let id: ID
        let title: String
        var badge: String?
    }

    struct Selector<ID: Hashable>: View {
        enum Style {
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

        init(
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

        init(
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

        var body: some View {
            switch style {
            case .menu:
                AppUI.Field(
                    label: label,
                    leadingSystemImage: icon,
                    errorMessage: errorMessage
                ) {
                    selectorMenu
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            case .segmented:
                AppUI.Field(
                    label: label,
                    errorMessage: errorMessage
                ) {
                    segmentedSelector
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }

        private var selectorMenu: some View {
            Menu {
                ForEach(allOptions) { option in
                    Button(option.title) {
                        setSelectedID(option.id)
                    }
                }
            } label: {
                HStack(spacing: GranaTheme.Spacing.sm) {
                    VStack(alignment: .trailing, spacing: GranaTheme.Spacing.xxs) {
                        Text(selectedTitle)
                            .font(GranaTheme.Typography.body)
                            .foregroundStyle(GranaTheme.Palette.ink)
                            .lineLimit(1)
                    }

                    if let badge = selectedBadge {
                        Text(badge)
                            .font(GranaTheme.Typography.caption2Emphasis)
                            .foregroundStyle(GranaTheme.Palette.tealDeep)
                            .padding(.horizontal, GranaTheme.Spacing.xs)
                            .padding(.vertical, GranaTheme.Spacing.xxs)
                            .background(
                                GranaTheme.Palette.teal.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: GranaTheme.Radius.pill, style: .continuous)
                            )
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: GranaTheme.IconSize.micro, weight: .semibold))
                        .foregroundStyle(GranaTheme.Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(.plain)
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
    }
}
