#if DEBUG
    import SwiftUI
    #if canImport(AppKit)
        import AppKit
    #endif

    enum TransactionFormPrototypeVariant: String, CaseIterable, Identifiable {
        case cards = "A"
        case unified = "B"
        case compact = "C"

        var id: String {
            rawValue
        }

        var name: String {
            switch self {
            case .cards:
                "Cards por decisão"
            case .unified:
                "Fluxo contínuo"
            case .compact:
                "Blocos compactos"
            }
        }

        var displayTitle: String {
            "\(rawValue) — \(name)"
        }

        var next: TransactionFormPrototypeVariant {
            let variants = Self.allCases
            guard let index = variants.firstIndex(of: self) else { return self }
            return variants[(index + 1) % variants.count]
        }

        var previous: TransactionFormPrototypeVariant {
            let variants = Self.allCases
            guard let index = variants.firstIndex(of: self) else { return self }
            return variants[(index - 1 + variants.count) % variants.count]
        }
    }

    struct TransactionFormPrototypeSnapshot {
        let title: String
        let summary: String
        let details: String
    }

    struct TransactionFormPrototypeDecorationData {
        struct StateRow: Identifiable {
            let label: String
            let value: String

            var id: String {
                label
            }
        }

        let title: String
        let kindLabel: String
        let kindColor: Color
        let amountText: String
        let chips: [String]
        let stateRows: [StateRow]
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

    struct TransactionFormPrototypeQuickAction: Identifiable {
        let title: String
        let action: () -> Void

        var id: String {
            title
        }
    }

    struct TransactionFormPrototypeAssumptionBanner: View {
        var body: some View {
            Text(
                "Protótipo descartável: três variações focadas no menor esforço de preenchimento do formulário dentro do drawer."
            )
            .font(GranaTheme.Typography.caption1)
            .foregroundStyle(GranaTheme.Palette.muted)
            .padding(.horizontal, GranaTheme.Spacing.md)
            .padding(.vertical, GranaTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.control)
        }
    }

    struct TransactionFormPrototypeCard<Content: View>: View {
        let title: String
        let subtitle: String?
        @ViewBuilder var content: () -> Content

        init(
            title: String,
            subtitle: String? = nil,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.title = title
            self.subtitle = subtitle
            self.content = content
        }

        var body: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text(title)
                        .font(GranaTheme.Typography.headline)
                        .foregroundStyle(GranaTheme.Palette.ink)

                    if let subtitle {
                        Text(subtitle)
                            .font(GranaTheme.Typography.footnote)
                            .foregroundStyle(GranaTheme.Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                content()
            }
            .padding(GranaTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
        }
    }

    struct TransactionFormPrototypePromptCard: View {
        let title: String
        let message: String

        var body: some View {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text(title)
                        .font(GranaTheme.Typography.caption1Emphasis)
                        .foregroundStyle(GranaTheme.Palette.tealDeep)

                    Text(message)
                        .font(GranaTheme.Typography.subheadline)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: GranaTheme.Spacing.none)
            }
            .padding(GranaTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
        }
    }

    struct TransactionFormPrototypeTextField: View {
        let title: String
        let placeholder: String
        @Binding var text: String

        var body: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                Text(title)
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(GranaTheme.Typography.bodyEmphasis)
                    .padding(.horizontal, GranaTheme.Spacing.md)
                    .padding(.vertical, GranaTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .background(fieldBackground)
            }
        }

        private var fieldBackground: some View {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                .fill(GranaTheme.Palette.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                        .stroke(GranaTheme.Palette.line, lineWidth: 1)
                )
        }
    }

    struct TransactionFormPrototypeCurrencyField: View {
        let title: String
        @Binding var cents: Int

        var body: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                Text(title)
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)

                HStack(spacing: GranaTheme.Spacing.sm) {
                    Text("R$")
                        .font(GranaTheme.Typography.moneyHeadline)
                        .foregroundStyle(GranaTheme.Palette.muted)

                    CurrencyField(cents: $cents)
                        .font(GranaTheme.Typography.moneyTitle3)
                }
                .padding(.horizontal, GranaTheme.Spacing.md)
                .padding(.vertical, GranaTheme.Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .background(fieldBackground)
            }
        }

        private var fieldBackground: some View {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                .fill(LinearGradient(
                    colors: [GranaTheme.Palette.paper, GranaTheme.Palette.backgroundStart],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                        .stroke(GranaTheme.Palette.line, lineWidth: 1)
                )
        }
    }

    struct TransactionFormPrototypeOptionSelector<ID: Hashable>: View {
        let title: String
        let subtitle: String?
        let options: [TransactionFormPrototypeOption<ID>]
        @Binding var selection: ID?
        var includesNoneOption = false
        var noneOptionTitle = "Nenhum"

        var body: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text(title)
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)

                    if let subtitle {
                        Text(subtitle)
                            .font(GranaTheme.Typography.caption2)
                            .foregroundStyle(GranaTheme.Palette.muted)
                    }
                }

                let columns = [
                    GridItem(.adaptive(minimum: 150, maximum: 240), spacing: GranaTheme.Spacing.sm),
                ]

                LazyVGrid(columns: columns, alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                    if includesNoneOption {
                        optionButton(
                            title: noneOptionTitle,
                            badge: nil,
                            isSelected: selection == nil
                        ) {
                            selection = nil
                        }
                    }

                    ForEach(options) { option in
                        optionButton(
                            title: option.title,
                            badge: option.badge,
                            isSelected: selection == option.id
                        ) {
                            selection = option.id
                        }
                    }
                }
            }
        }

        private func optionButton(
            title: String,
            badge: String?,
            isSelected: Bool,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    if let badge, !badge.isEmpty {
                        Text(badge.uppercased())
                            .font(GranaTheme.Typography.caption2)
                            .foregroundStyle(isSelected ? GranaTheme.Palette.tealDeep : GranaTheme.Palette.muted)
                    }

                    Text(title)
                        .font(isSelected ? GranaTheme.Typography.subheadlineEmphasis : GranaTheme.Typography
                            .subheadline)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(GranaTheme.Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                .background(buttonBackground(isSelected: isSelected))
            }
            .buttonStyle(.plain)
        }

        private func buttonBackground(isSelected: Bool) -> some View {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                .fill(isSelected ? GranaTheme.Palette.teal.opacity(0.12) : GranaTheme.Palette.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                        .stroke(isSelected ? GranaTheme.Palette.teal : GranaTheme.Palette.line, lineWidth: 1)
                )
        }
    }

    struct TransactionFormPrototypeDateSelector: View {
        @Binding var selection: Date
        let calendar: Calendar
        let quickActions: [TransactionFormPrototypeQuickAction]

        var body: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                prototypeHeader(
                    title: "Data",
                    detail: selection.formatted(date: .abbreviated, time: .omitted)
                )

                quickActionRow

                DatePicker("", selection: $selection, displayedComponents: [.date])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .padding(.horizontal, GranaTheme.Spacing.md)
                    .padding(.vertical, GranaTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(controlBackground)
            }
        }

        private var quickActionRow: some View {
            HStack(spacing: GranaTheme.Spacing.sm) {
                ForEach(quickActions) { quickAction in
                    Button(quickAction.title, action: quickAction.action)
                        .buttonStyle(TransactionFormPrototypeQuickActionStyle())
                }
            }
        }

        private func prototypeHeader(title: String, detail: String) -> some View {
            HStack {
                Text(title)
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)

                Spacer(minLength: GranaTheme.Spacing.none)

                Text(detail)
                    .font(GranaTheme.Typography.subheadlineEmphasis)
                    .foregroundStyle(GranaTheme.Palette.ink)
            }
        }

        private var controlBackground: some View {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                .fill(GranaTheme.Palette.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                        .stroke(GranaTheme.Palette.line, lineWidth: 1)
                )
        }
    }

    struct TransactionFormPrototypeTimeSelector: View {
        @Binding var selection: Date
        let quickActions: [TransactionFormPrototypeQuickAction]

        var body: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                prototypeHeader(
                    title: "Hora",
                    detail: selection.formatted(date: .omitted, time: .shortened)
                )

                quickActionRow

                DatePicker("", selection: $selection, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .padding(.horizontal, GranaTheme.Spacing.md)
                    .padding(.vertical, GranaTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(controlBackground)
            }
        }

        private var quickActionRow: some View {
            HStack(spacing: GranaTheme.Spacing.sm) {
                ForEach(quickActions) { quickAction in
                    Button(quickAction.title, action: quickAction.action)
                        .buttonStyle(TransactionFormPrototypeQuickActionStyle())
                }
            }
        }

        private func prototypeHeader(title: String, detail: String) -> some View {
            HStack {
                Text(title)
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)

                Spacer(minLength: GranaTheme.Spacing.none)

                Text(detail)
                    .font(GranaTheme.Typography.subheadlineEmphasis)
                    .foregroundStyle(GranaTheme.Palette.ink)
            }
        }

        private var controlBackground: some View {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                .fill(GranaTheme.Palette.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                        .stroke(GranaTheme.Palette.line, lineWidth: 1)
                )
        }
    }

    struct TransactionFormPrototypeQuickActionStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(GranaTheme.Typography.caption1Emphasis)
                .foregroundStyle(GranaTheme.Palette.tealDeep)
                .padding(.horizontal, GranaTheme.Spacing.sm)
                .padding(.vertical, GranaTheme.Spacing.xs)
                .background(
                    Capsule()
                        .fill(configuration.isPressed ? GranaTheme.Palette.teal.opacity(0.18) : GranaTheme.Palette.soft)
                )
        }
    }

    struct TransactionFormPrototypeNotesField: View {
        @Binding var text: String

        var body: some View {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                Text("Anotação opcional")
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Contexto extra, observação, lembrete…")
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
                .background(fieldBackground)
            }
        }

        private var fieldBackground: some View {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                .fill(GranaTheme.Palette.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
                        .stroke(GranaTheme.Palette.line, lineWidth: 1)
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

    struct TransactionFormPrototypeLiveSummaryCard: View {
        let data: TransactionFormPrototypeDecorationData

        var body: some View {
            TransactionFormPrototypeCard(title: "Estado ao vivo") {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                    HStack(alignment: .center, spacing: GranaTheme.Spacing.sm) {
                        Text(data.kindLabel)
                            .font(GranaTheme.Typography.caption1Emphasis)
                            .foregroundStyle(data.kindColor)

                        Spacer(minLength: GranaTheme.Spacing.none)

                        Text(data.amountText)
                            .font(GranaTheme.Typography.moneySubheadline)
                            .foregroundStyle(GranaTheme.Palette.ink)
                    }

                    HStack(spacing: GranaTheme.Spacing.xs) {
                        ForEach(data.chips, id: \.self) { chip in
                            Text(chip)
                                .font(GranaTheme.Typography.caption2)
                                .foregroundStyle(GranaTheme.Palette.ink)
                                .padding(.horizontal, GranaTheme.Spacing.sm)
                                .padding(.vertical, GranaTheme.Spacing.xs)
                                .background(
                                    Capsule()
                                        .fill(GranaTheme.Palette.soft)
                                )
                        }
                    }

                    ForEach(data.stateRows) { row in
                        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                            Text(row.label)
                                .font(GranaTheme.Typography.caption1)
                                .foregroundStyle(GranaTheme.Palette.muted)
                                .frame(width: 58, alignment: .leading)
                            Text(row.value)
                                .font(GranaTheme.Typography.subheadlineEmphasis)
                                .foregroundStyle(GranaTheme.Palette.ink)
                        }
                    }
                }
            }
        }
    }

    struct TransactionFormPrototypeSwitcher: View {
        @Binding var variant: TransactionFormPrototypeVariant
        let snapshot: TransactionFormPrototypeSnapshot
        let onPrevious: () -> Void
        let onNext: () -> Void

        var body: some View {
            HStack(spacing: GranaTheme.Spacing.sm) {
                prototypeButton(systemImage: "arrow.left", title: "Variante anterior", action: onPrevious)

                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text(snapshot.title)
                        .font(GranaTheme.Typography.subheadlineEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)

                    Text(snapshot.summary)
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .lineLimit(1)

                    Text(snapshot.details)
                        .font(GranaTheme.Typography.caption2)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                prototypeButton(systemImage: "arrow.right", title: "Próxima variante", action: onNext)
            }
            .padding(.horizontal, GranaTheme.Spacing.md)
            .padding(.vertical, GranaTheme.Spacing.sm)
            .frame(maxWidth: 460, alignment: .leading)
            .background(
                Capsule(style: .continuous)
                    .fill(GranaTheme.Palette.paperSolid.opacity(0.98))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(GranaTheme.Palette.line, lineWidth: 1)
            )
            .shadow(color: GranaTheme.Shadow.cardColor, radius: 18, x: 0, y: 8)
            .background(
                TransactionFormPrototypeKeyboardMonitor(onPrevious: onPrevious, onNext: onNext)
                    .frame(width: 0, height: 0)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Seletor de variantes do protótipo")
            .accessibilityValue(variant.displayTitle)
        }

        private func prototypeButton(
            systemImage: String,
            title: String,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(GranaTheme.Palette.background)
                    )
            }
            .buttonStyle(.plain)
            .help(title)
            .accessibilityLabel(title)
        }
    }

    #if canImport(AppKit)
        struct TransactionFormPrototypeKeyboardMonitor: NSViewRepresentable {
            let onPrevious: () -> Void
            let onNext: () -> Void

            func makeCoordinator() -> Coordinator {
                Coordinator(onPrevious: onPrevious, onNext: onNext)
            }

            func makeNSView(context: Context) -> NSView {
                let view = NSView(frame: .zero)
                context.coordinator.installMonitor()
                return view
            }

            func updateNSView(_ nsView: NSView, context: Context) {
                context.coordinator.onPrevious = onPrevious
                context.coordinator.onNext = onNext
            }

            static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
                coordinator.removeMonitor()
            }

            final class Coordinator {
                var onPrevious: () -> Void
                var onNext: () -> Void
                private var monitor: Any?

                init(
                    onPrevious: @escaping () -> Void,
                    onNext: @escaping () -> Void
                ) {
                    self.onPrevious = onPrevious
                    self.onNext = onNext
                }

                func installMonitor() {
                    guard monitor == nil else { return }

                    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                        guard let self else { return event }
                        guard self.shouldHandle(event: event) else { return event }

                        switch event.keyCode {
                        case 123:
                            onPrevious()
                            return nil
                        case 124:
                            onNext()
                            return nil
                        default:
                            return event
                        }
                    }
                }

                func removeMonitor() {
                    guard let monitor else { return }
                    NSEvent.removeMonitor(monitor)
                    self.monitor = nil
                }

                private func shouldHandle(event: NSEvent) -> Bool {
                    guard event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask) else {
                        return false
                    }
                    guard let responder = NSApp.keyWindow?.firstResponder else { return true }

                    if let textView = responder as? NSTextView, textView.isEditable || textView.isFieldEditor {
                        return false
                    }

                    if responder is NSTextField {
                        return false
                    }

                    return true
                }
            }
        }
    #endif
#endif
