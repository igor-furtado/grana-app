import SwiftUI

struct DesignSystemView: View {
    @State private var selectedSection: AtlasSection = .foundations

    private let paletteTokens: [TokenRowModel] = [
        TokenRowModel(name: "background", value: "#f4f0e8", swatch: GranaTheme.Palette.background),
        TokenRowModel(name: "backgroundStart", value: "#f8f3e8", swatch: GranaTheme.Palette.backgroundStart),
        TokenRowModel(name: "backgroundEnd", value: "#edf4ef", swatch: GranaTheme.Palette.backgroundEnd),
        TokenRowModel(name: "ink", value: "#17231f", swatch: GranaTheme.Palette.ink),
        TokenRowModel(name: "muted", value: "ink 62%", swatch: GranaTheme.Palette.muted),
        TokenRowModel(name: "line", value: "ink 13%", swatch: GranaTheme.Palette.line),
        TokenRowModel(name: "paper", value: "#fffcf5", swatch: GranaTheme.Palette.paper),
        TokenRowModel(name: "paperSolid", value: "#fffaf0", swatch: GranaTheme.Palette.paperSolid),
        TokenRowModel(name: "teal", value: "#117a68", swatch: GranaTheme.Palette.teal),
        TokenRowModel(name: "tealDeep", value: "#0c5f53", swatch: GranaTheme.Palette.tealDeep),
        TokenRowModel(name: "green", value: "#147c56", swatch: GranaTheme.Palette.green),
        TokenRowModel(name: "red", value: "#c9413a", swatch: GranaTheme.Palette.red),
        TokenRowModel(name: "amber", value: "#d8912b", swatch: GranaTheme.Palette.amber),
        TokenRowModel(name: "gold", value: "#edb85f", swatch: GranaTheme.Palette.gold),
        TokenRowModel(name: "creamText", value: "#fff9ed", swatch: GranaTheme.Palette.creamText),
    ]

    private let radiusTokens: [RadiusToken] = [
        RadiusToken(name: "control", radius: GranaTheme.Radius.control, usage: "Botões e controles compactos"),
        RadiusToken(name: "pill", radius: GranaTheme.Radius.pill, usage: "Inputs e badges"),
        RadiusToken(name: "card", radius: GranaTheme.Radius.card, usage: "Cards de conteúdo"),
        RadiusToken(name: "rail", radius: GranaTheme.Radius.rail, usage: "Shell lateral autenticado"),
        RadiusToken(name: "hero", radius: GranaTheme.Radius.hero, usage: "Header e agrupamentos amplos"),
    ]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            AppUI.Layout.ScreenHeader(
                title: "Design System",
                subtitle: "Mapa vivo de tokens, componentes e exemplos para consultar o sistema sem perder a visão do todo."
            )

            ScrollViewReader { proxy in
                HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                    AtlasNavigationCard(
                        selectedSection: $selectedSection,
                        sections: AtlasSection.allCases
                    ) { section in
                        scrollToSection(section, using: proxy)
                    }
                    .frame(width: 280)

                    ScrollView {
                        atlasSections
                            .padding(.bottom, GranaTheme.Spacing.lg)
                    }
                }
            }
        }
        .background(.clear)
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
    }

    private var atlasSections: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xl) {
            foundationsSection
                .id(AtlasSection.foundations)
            basicComponentsSection
                .id(AtlasSection.basicComponents)
            combinedComponentsSection
                .id(AtlasSection.combinedComponents)
            complexComponentsSection
                .id(AtlasSection.complexComponents)
            templatesSection
                .id(AtlasSection.templates)
        }
    }

    private var foundationsSection: some View {
        AtlasSectionContainer(
            eyebrow: AtlasSection.foundations.eyebrow,
            title: "Fundamentos do sistema visual.",
            subtitle: "Os tokens-base ficam reunidos para leitura rápida: cor, tipografia, espaçamento, profundidade e forma."
        ) {
            DesignSystemCard(title: "Paleta de cores") {
                CompactPaletteGrid(tokens: paletteTokens)
            }
            DesignSystemCard(title: "Fontes") {
                HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                    TypographyColumn(
                        title: "Texto",
                        tokens: textTypographyTokens
                    )
                    TypographyColumn(
                        title: "Dinheiro",
                        tokens: moneyTypographyTokens
                    )
                }
            }
            DesignSystemCard(title: "Espaçamentos") {
                SpacingTable(tokens: GranaTheme.Spacing.tokens)
            }
            DesignSystemCard(title: "Sombras") {
                SurfaceDepthLayers()
            }
            DesignSystemCard(title: "Raios") {
                RadiusTable(tokens: radiusTokens)
            }
        }
    }

    private var basicComponentsSection: some View {
        AtlasSectionContainer(
            eyebrow: AtlasSection.basicComponents.eyebrow,
            title: "Peças atômicas do catálogo.",
            subtitle: "Aqui entram os blocos mais básicos, isolados para deixar claro o vocabulário mínimo da interface."
        ) {
            DesignSystemCard(title: "Botão") {
                ButtonsShowcase()
            }
            DesignSystemCard(title: "Formulário") {
                VStack(spacing: GranaTheme.Spacing.sm) {
                    BasicTextFieldShowcase()
                    CurrencyFieldShowcase()
                    SelectorShowcase()
                    ToggleShowcase()
                    DatePickerShowcase()
                }
                .padding(GranaTheme.Spacing.md)
                .tableSurface()
            }
            DesignSystemCard(title: "Ícone") {
                IconShowcase()
            }
        }
    }

    private var combinedComponentsSection: some View {
        AtlasSectionContainer(
            eyebrow: AtlasSection.combinedComponents.eyebrow,
            title: "Combinações recorrentes da interface.",
            subtitle: "Esses blocos já juntam mais de um elemento básico e mostram padrões de uso mais próximos da aplicação."
        ) {
            DesignSystemCard(title: "Barra de pesquisa") {
                SearchBarShowcase()
            }
            DesignSystemCard(title: "Tabelas") {
                TablesShowcase()
            }
        }
    }

    private var complexComponentsSection: some View {
        AtlasSectionContainer(
            eyebrow: AtlasSection.complexComponents.eyebrow,
            title: "Estruturas maiores de navegação e contexto.",
            subtitle: "Esses componentes enquadram a experiência e organizam a leitura da tela inteira."
        ) {
            DesignSystemCard(title: "Rail") {
                RailShowcase()
            }
            DesignSystemCard(title: "Header") {
                HeaderShowcase()
            }
        }
    }

    private var templatesSection: some View {
        AtlasSectionContainer(
            eyebrow: AtlasSection.templates.eyebrow,
            title: "Templates para validar o sistema em escala.",
            subtitle: "No fim, os templates mostram como os mesmos blocos sobem para telas mais densas e reais."
        ) {
            DesignSystemCard(title: "Dashboard") {
                DashboardExample()
            }
            DesignSystemCard(title: "Transações") {
                TransactionsTableExample()
            }
        }
    }

    private var visibleTypographyTokens: [GranaTheme.Typography.Token] {
        GranaTheme.Typography.tokens.filter { $0.family != .code }
    }

    private var textTypographyTokens: [GranaTheme.Typography.Token] {
        visibleTypographyTokens.filter { $0.family == .text }
    }

    private var moneyTypographyTokens: [GranaTheme.Typography.Token] {
        visibleTypographyTokens.filter { $0.family == .money }
    }

    private func scrollToSection(_ section: AtlasSection, using proxy: ScrollViewProxy) {
        selectedSection = section
        withAnimation(.easeInOut(duration: 0.22)) {
            proxy.scrollTo(section, anchor: .top)
        }
    }
}

private struct DesignSystemCard<Content: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let content: () -> Content

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            Text(title)
                .font(GranaTheme.Typography.headline)
                .foregroundStyle(GranaTheme.Palette.ink)
            content()
        }
        .padding(.top, GranaTheme.Spacing.md)
        .padding(.trailing, GranaTheme.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct AtlasSectionContainer<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let content: () -> Content

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            DesignSystemSectionHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            )
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DesignSystemSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
            Text(eyebrow)
                .font(GranaTheme.Typography.caption1Emphasis)
                .foregroundStyle(GranaTheme.Palette.tealDeep)
            Text(title)
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)
            Text(subtitle)
                .font(GranaTheme.Typography.subheadline)
                .foregroundStyle(GranaTheme.Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DesignSystemPrinciplesSummary: View {
    private let rows = [
        ("Superfícies", "Glass só no chrome; cards usam subtle; tabelas usam solid."),
        ("Tipografia", "Texto em tokens; dinheiro monoespaçado; código separado."),
        ("Semântica", "Teal é interação. Receita, despesa e transferência mantêm significado próprio."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text(row.0)
                        .font(GranaTheme.Typography.subheadlineEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)
                    Text(row.1)
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if row.0 != rows.last?.0 {
                    TableDivider()
                        .padding(.leading, GranaTheme.Spacing.none)
                }
            }
        }
        .padding(GranaTheme.Spacing.md)
        .tableSurface()
    }
}

private struct AtlasNavigationCard: View {
    @Binding var selectedSection: AtlasSection
    let sections: [AtlasSection]
    let onSelect: (AtlasSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                Text("Mapa")
                    .font(GranaTheme.Typography.caption1Emphasis)
                    .foregroundStyle(GranaTheme.Palette.tealDeep)
                Text("Atlas da tela")
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.ink)
                Text("Use como índice: cada bloco responde uma pergunta diferente sobre o sistema.")
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                ForEach(sections) { section in
                    Button {
                        onSelect(section)
                    } label: {
                        AtlasNavigationRow(
                            section: section,
                            isSelected: selectedSection == section
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
    }
}

private struct AtlasNavigationRow: View {
    let section: AtlasSection
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
            Circle()
                .fill(isSelected ? GranaTheme.Palette.teal : GranaTheme.Palette.line)
                .frame(width: 10, height: 10)
                .padding(.top, GranaTheme.Spacing.xxs)

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                Text(section.eyebrow)
                    .font(GranaTheme.Typography.subheadlineEmphasis)
                    .foregroundStyle(isSelected ? GranaTheme.Palette.ink : GranaTheme.Palette.muted)
                Text(section.summary)
                    .font(GranaTheme.Typography.caption1)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: GranaTheme.Spacing.none)
        }
        .padding(.horizontal, GranaTheme.Spacing.sm)
        .padding(.vertical, GranaTheme.Spacing.sm)
        .background(
            isSelected ? GranaTheme.Palette.teal.opacity(0.10) : GranaTheme.Palette.soft,
            in: RoundedRectangle(cornerRadius: GranaTheme.Radius.control, style: .continuous)
        )
    }
}

private enum AtlasSection: String, CaseIterable, Identifiable {
    case foundations
    case basicComponents
    case combinedComponents
    case complexComponents
    case templates

    var id: String {
        rawValue
    }

    var eyebrow: String {
        switch self {
        case .foundations:
            "Fundamentos"
        case .basicComponents:
            "Componentes básicos"
        case .combinedComponents:
            "Componentes combinados"
        case .complexComponents:
            "Componentes complexos"
        case .templates:
            "Templates"
        }
    }

    var summary: String {
        switch self {
        case .foundations:
            "Paleta de cores, fontes, espaçamentos, sombras e raios."
        case .basicComponents:
            "Botão, texto, picker, date picker, currency field, selector, ícone e toggle."
        case .combinedComponents:
            "Barra de pesquisa, e tabelas."
        case .complexComponents:
            "Rail e header."
        case .templates:
            "Dashboard e transações."
        }
    }
}

private struct TokenRowModel: Identifiable {
    let name: String
    let value: String
    let swatch: Color

    var id: String {
        name
    }
}

private struct RadiusToken: Identifiable {
    let name: String
    let radius: CGFloat
    let usage: String
    var note: String?

    var id: String {
        name
    }

    var value: String {
        "\(Int(radius)) pt"
    }
}

private struct TokenTable: View {
    let tokens: [TokenRowModel]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                TokenTableRow(token: token)
                if index < tokens.count - 1 {
                    TableDivider()
                }
            }
        }
        .tableSurface()
    }
}

private struct CompactPaletteGrid: View {
    let tokens: [TokenRowModel]

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: GranaTheme.Spacing.sm)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            ForEach(tokens) { token in
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(token.swatch)
                        .frame(height: 32)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(GranaTheme.Palette.line, lineWidth: 1)
                        }

                    Text(token.name)
                        .font(GranaTheme.Typography.caption1Emphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)

                    Text(token.value)
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(GranaTheme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tableSurface()
            }
        }
    }
}

private struct TokenTableRow: View {
    let token: TokenRowModel

    var body: some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(token.swatch)
                .frame(width: 34, height: 34)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(GranaTheme.Palette.line, lineWidth: 1)
                }

            TableText(primary: token.name, secondary: token.value)
        }
        .tableRowContent()
    }
}

private struct TypographyColumn: View {
    let title: String
    let tokens: [GranaTheme.Typography.Token]

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            Text(title)
                .font(GranaTheme.Typography.caption1Emphasis)
                .foregroundStyle(GranaTheme.Palette.tealDeep)

            TypographyTable(tokens: tokens)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct TypographyTable: View {
    let tokens: [GranaTheme.Typography.Token]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: GranaTheme.Spacing.sm) {
                    Text(sampleText(for: token))
                        .font(token.font)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .frame(width: 112, alignment: .leading)

                    TableText(
                        primary: token.name,
                        secondary: "\(resolvedValue(for: token)) · \(token.usage)"
                    )
                }
                .tableRowContent()

                if index < tokens.count - 1 {
                    TableDivider()
                }
            }
        }
        .tableSurface()
    }

    private func resolvedValue(for token: GranaTheme.Typography.Token) -> String {
        "\(token.value) · \(token.category)"
    }

    private func sampleText(for token: GranaTheme.Typography.Token) -> String {
        switch token.family {
        case .text:
            "AaB"
        case .money:
            "R$0"
        case .code:
            "AaB"
        }
    }
}

private struct RadiusTable: View {
    let tokens: [RadiusToken]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: GranaTheme.Spacing.sm) {
                    RadiusPreview(radius: token.radius)
                    TableText(primary: token.name, secondary: "\(token.value) · \(token.usage)")

                    if let note = token.note {
                        Text(note)
                            .font(GranaTheme.Typography.caption2Emphasis)
                            .foregroundStyle(GranaTheme.Palette.tealDeep)
                            .padding(.horizontal, GranaTheme.Spacing.xs)
                            .padding(.vertical, GranaTheme.Spacing.xxs)
                            .background(GranaTheme.Palette.teal.opacity(0.10), in: Capsule())
                    }
                }
                .tableRowContent()

                if index < tokens.count - 1 {
                    TableDivider()
                }
            }
        }
        .tableSurface()
    }
}

private struct SpacingTable: View {
    let tokens: [GranaTheme.Spacing.Token]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: GranaTheme.Spacing.sm) {
                    SpacingPreview(value: token.value)

                    TableText(
                        primary: token.name,
                        secondary: "\(token.displayValue) · \(token.usage)"
                    )
                }
                .tableRowContent()

                if index < tokens.count - 1 {
                    TableDivider()
                }
            }
        }
        .tableSurface()
    }
}

private struct SpacingPreview: View {
    let value: CGFloat

    var body: some View {
        HStack(spacing: value) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(GranaTheme.Palette.teal.opacity(0.82))
                .frame(width: 18, height: 28)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(GranaTheme.Palette.gold.opacity(0.82))
                .frame(width: 18, height: 28)
        }
        .frame(width: 92, alignment: .leading)
    }
}

private struct RadiusPreview: View {
    let radius: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(GranaTheme.Palette.teal.opacity(0.14))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(GranaTheme.Palette.teal.opacity(0.82), lineWidth: 1.3)
            Path { path in
                path.move(to: CGPoint(x: radius, y: 0))
                path.addLine(to: CGPoint(x: radius, y: radius))
                path.addLine(to: CGPoint(x: 0, y: radius))
            }
            .stroke(
                GranaTheme.Palette.tealDeep.opacity(0.46),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )
        }
        .frame(width: 92, height: 52)
    }
}

private struct SurfaceDepthLayers: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            DepthSample(
                title: "shell glass",
                subtitle: "Somente navegação e chrome estrutural",
                prominence: .glass,
                width: 280,
                offset: CGSize(width: 16, height: 28)
            )

            DepthSample(
                title: "content card",
                subtitle: "Sem blur, com sombra baixa",
                prominence: .subtle,
                width: 250,
                offset: CGSize(width: 102, height: 122)
            )

            DepthSample(
                title: "solid row",
                subtitle: "Único papel com linha aparente",
                prominence: .solid,
                width: 230,
                offset: CGSize(width: 152, height: 210)
            )
        }
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
    }
}

private struct DepthSample: View {
    let title: String
    let subtitle: String
    let prominence: GranaSurfaceProminence
    let width: CGFloat
    let offset: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
            Text(title)
                .font(GranaTheme.Typography.code)
                .foregroundStyle(GranaTheme.Palette.ink)
            Text(subtitle)
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(GranaTheme.Palette.muted)
            Capsule()
                .fill(GranaTheme.Palette.teal)
                .frame(width: 160, height: 8)
            Capsule()
                .fill(GranaTheme.Palette.line)
                .frame(width: 220, height: 8)
        }
        .padding(GranaTheme.Spacing.lg)
        .frame(width: width, height: 132, alignment: .topLeading)
        .granaSurface(prominence, cornerRadius: GranaTheme.Radius.card)
        .offset(offset)
    }
}

private struct ButtonsShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            HStack(spacing: GranaTheme.Spacing.xs) {
                Button("Primário") {}
                    .buttonStyle(GranaPrimaryButtonStyle())
                Button("Secundário") {}
                    .buttonStyle(GranaSecondaryButtonStyle())
                Button {} label: {
                    Label("Salvar", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(GranaPrimaryButtonStyle())

                Button {} label: {
                    Label("Filtrar", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(GranaSecondaryButtonStyle())
            }

            HStack(spacing: GranaTheme.Spacing.xs) {
                Button("Sistema") {}
                    .buttonStyle(.bordered)
                Button("Destrutivo") {}
                    .buttonStyle(.bordered)
                    .tint(.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BasicTextFieldShowcase: View {
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            AppUI.TextField(
                label: "Campo de texto",
                text: $email,
                placeholder: "voce@exemplo.com",
                textAlignment: .trailing
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IconShowcase: View {
    private let icons: [(AppIcon, String)] = [
        (.sidebarDashboard, "Dashboard"),
        (.sidebarTransactions, "Transações"),
        (.add, "Adicionar"),
        (.success, "Sucesso"),
    ]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            ForEach(Array(icons.enumerated()), id: \.offset) { index, row in
                HStack(spacing: GranaTheme.Spacing.sm) {
                    Image(systemName: row.0.systemImage)
                        .font(.system(size: GranaTheme.IconSize.medium, weight: .semibold))
                        .foregroundStyle(GranaTheme.Palette.tealDeep)
                        .frame(width: 32, height: 32)
                        .background(
                            GranaTheme.Palette.teal.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    TableText(primary: row.1, secondary: row.0.systemImage)
                }
                .tableRowContent()

                if index < icons.count - 1 {
                    TableDivider()
                }
            }
        }
        .tableSurface()
    }
}

private struct ToggleShowcase: View {
    @State private var isOn = true

    var body: some View {
        AppUI.Toggle(
            label: "Toggle",
            isOn: $isOn,
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DatePickerShowcase: View {
    @State private var date = Date.now
    @State private var time = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            AppUI.DatePicker(
                label: "Data",
                selection: $date,
            )

            AppUI.DatePicker(
                label: "Hora",
                selection: $time,
                displayedComponents: [.hourAndMinute],
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CurrencyFieldShowcase: View {
    @State private var cents = 123_456

    var body: some View {
        AppUI.CurrencyField(
            label: "Valor monetário",
            cents: $cents,
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SearchBarShowcase: View {
    @State private var query = "assinatura"

    var body: some View {
        AppUI.TextField(
            label: "Campo monetário",
            text: $query,
            placeholder: "Descrição, categoria ou nota",
            leadingSystemImage: "magnifyingglass",
            showsClearButton: true,
            textAlignment: .leading,
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SelectorShowcase: View {
    @State private var selectedCategoryID: String? = "alimentacao"

    private let options: [AppUI.SelectorOption<String>] = [
        .init(id: "alimentacao", title: "Alimentação", badge: nil),
        .init(id: "moradia", title: "Moradia", badge: nil),
        .init(id: "transporte", title: "Transporte", badge: nil),
    ]

    var body: some View {
        AppUI.Selector(
            label: "Seletor",
            options: options,
            selection: $selectedCategoryID,
            includesNoneOption: true,
            noneOptionTitle: "Sem categoria",
            icon: "tag",
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TablesShowcase: View {
    var body: some View {
        TransactionsTableExample()
            .frame(height: 280)
    }
}

private struct RailShowcase: View {
    @State private var selection: AppSection = .designSystem

    var body: some View {
        AppNavigationRail(selection: selection) { newSelection in
            selection = newSelection
        }
        .frame(height: 360)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeaderShowcase: View {
    var body: some View {
        AppUI.Layout.ScreenHeader(
            title: "Transações",
            subtitle: "Leitura compacta do contexto da tela e das ações principais."
        ) {
            Button("Exportar") {}
                .buttonStyle(GranaSecondaryButtonStyle())
            Button("Nova transação") {}
                .buttonStyle(GranaPrimaryButtonStyle())
        }
    }
}

private struct DashboardExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 210), spacing: GranaTheme.Spacing.sm)],
                spacing: GranaTheme.Spacing.sm
            ) {
                TypographyMetricCard(
                    title: "Receitas",
                    value: Decimal(12400),
                    icon: .incomeFlow,
                    accent: .income
                )
                TypographyMetricCard(
                    title: "Despesas",
                    value: Decimal(7850),
                    icon: .expenseFlow,
                    accent: .expense
                )
                TypographyMetricCard(
                    title: "Saldo mensal",
                    value: Decimal(4550),
                    icon: .balance,
                    accent: .success
                )
                TypographyMetricCard(
                    title: "Investimentos",
                    value: Decimal(0),
                    icon: .netResult,
                    accent: .transfer,
                    placeholder: true
                )
            }

            HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                MiniChartPanel()
                CategoryRankingPanel()
            }
        }
    }
}

private struct TypographyMetricCard: View {
    let title: String
    let value: Decimal
    let icon: AppIcon?
    let accent: Color
    var placeholder = false

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            HStack(spacing: GranaTheme.Spacing.xxs) {
                if let icon {
                    Image(systemName: icon.systemImage)
                        .font(.system(size: GranaTheme.IconSize.small, weight: .bold))
                        .foregroundStyle(accent)
                }

                Text(title)
                    .font(GranaTheme.Typography.subheadlineEmphasis)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }

            Text(placeholder ? "—" : value.formatted(.currency(code: "BRL")))
                .font(GranaTheme.Typography.moneyTitle2)
                .foregroundStyle(placeholder ? GranaTheme.Palette.muted : GranaTheme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(GranaTheme.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }
}

private struct MiniChartPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            Text("Fluxo do mês")
                .font(GranaTheme.Typography.subheadlineEmphasis)
                .foregroundStyle(GranaTheme.Palette.muted)

            HStack(alignment: .bottom, spacing: GranaTheme.Spacing.xs) {
                ForEach([0.42, 0.74, 0.56, 0.88, 0.63, 0.92], id: \.self) { value in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(GranaTheme.Palette.teal.opacity(0.24 + value * 0.42))
                        .frame(width: 28, height: 120 * value)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .bottomLeading)
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }
}

private struct CategoryRankingPanel: View {
    private let rows = [
        ("Mercado", "R$ 2.180", Color.expense, 0.86),
        ("Moradia", "R$ 1.950", Color.transfer, 0.76),
        ("Transporte", "R$ 740", Color.warning, 0.42),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            Text("Categorias")
                .font(GranaTheme.Typography.subheadlineEmphasis)
                .foregroundStyle(GranaTheme.Palette.muted)

            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    HStack {
                        Text(row.0)
                            .font(GranaTheme.Typography.subheadlineEmphasis)
                        Spacer()
                        Text(row.1)
                            .font(GranaTheme.Typography.moneyFootnote)
                            .foregroundStyle(GranaTheme.Palette.muted)
                    }
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(row.2.opacity(0.18))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(row.2)
                                    .frame(width: proxy.size.width * row.3)
                            }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }
}

private struct TransactionsTableExample: View {
    @State private var selectedRows: Set<String> = ["Mercado União", "Salário"]
    @State private var sortOrder = [
        KeyPathComparator(\TransactionPreview.description),
    ]
    @State private var filterText = ""

    private let rows: [TransactionPreview] = [
        TransactionPreview(
            institution: .inter,
            description: "Mercado União",
            memo: "Alimentação",
            amount: Decimal(238),
            amountKind: .outgoing,
            status: TransactionRow.Status(label: "Revisada", tint: .success)
        ),
        TransactionPreview(
            institution: .itau,
            description: "Salário",
            memo: "Receita mensal",
            amount: Decimal(12200),
            amountKind: .incoming,
            status: nil
        ),
        TransactionPreview(
            institution: .c6,
            description: "Assinatura",
            memo: "Streaming",
            amount: Decimal(43),
            amountKind: .outgoing,
            status: TransactionRow.Status(label: "Pendente", tint: .warning)
        ),
        TransactionPreview(
            institution: .inter,
            description: "Reserva",
            memo: "Transferência entre contas",
            amount: Decimal(1500),
            amountKind: .transfer,
            status: TransactionRow.Status(label: "Neutra", tint: .neutral)
        ),
    ]

    var body: some View {
        AppUI.Table(filteredRows, selection: $selectedRows, sortOrder: $sortOrder) {
            TableColumn("Instituição", value: \.institutionName) { (row: TransactionPreview) in
                HStack(spacing: GranaTheme.Spacing.sm) {
                    InstitutionIcon(kind: row.institution, size: 24)
                    Text(row.institutionName)
                        .font(GranaTheme.Typography.subheadlineEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)
                }
            }
            .width(min: 160, ideal: 180, max: 220)

            TableColumn("Transação", value: \.description) { (row: TransactionPreview) in
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text(row.description)
                        .font(GranaTheme.Typography.subheadlineEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)
                    Text(row.memo)
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)
                }
            }
            .width(min: 220, ideal: 280)

            TableColumn("Status", value: \.statusRank) { (row: TransactionPreview) in
                Text(row.statusLabel)
                    .font(GranaTheme.Typography.caption1Emphasis)
                    .foregroundStyle(row.statusColor)
            }
            .width(min: 92, ideal: 110, max: 132)

            TableColumn("Valor", value: \.amount) { (row: TransactionPreview) in
                Text(row.amount.formatted(.currency(code: "BRL")))
                    .font(GranaTheme.Typography.moneySubheadline)
                    .foregroundStyle(row.amountColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 120, ideal: 148, max: 180)
        } filterBar: {
            HStack(spacing: GranaTheme.Spacing.sm) {
                AppUI.TextField(
                    label: "Transação",
                    text: $filterText,
                    placeholder: "Buscar descrição",
                    leadingSystemImage: "magnifyingglass",
                    showsClearButton: true,
                    font: GranaTheme.Typography.footnoteEmphasis,
                    textAlignment: .leading
                )
                .frame(width: 240)
            }
        }
        .frame(height: 300)
    }

    private var filteredRows: [TransactionPreview] {
        rows
            .filter { row in
                filterText.isEmpty
                    || row.description.localizedCaseInsensitiveContains(filterText)
                    || row.memo.localizedCaseInsensitiveContains(filterText)
            }
            .sorted(using: sortOrder)
    }
}

private struct TransactionPreview: Identifiable {
    let institution: InstitutionKind
    let description: String
    let memo: String
    let amount: Decimal
    let amountKind: TransactionRow.AmountKind
    let status: TransactionRow.Status?

    var id: String {
        description
    }

    var institutionName: String {
        institution.displayName
    }

    var statusLabel: String {
        status?.label ?? "Sem status"
    }

    var statusRank: Int {
        switch status?.tint {
        case .success?: 0
        case .warning?: 1
        case .info?: 2
        case .neutral?: 3
        case nil: 4
        }
    }

    var statusColor: Color {
        switch status?.tint {
        case .success?: GranaTheme.Palette.green
        case .warning?: GranaTheme.Palette.amber
        case .info?: GranaTheme.Palette.tealDeep
        case .neutral?: GranaTheme.Palette.muted
        case nil: GranaTheme.Palette.muted
        }
    }

    var amountColor: Color {
        switch amountKind {
        case .incoming:
            GranaTheme.Palette.green
        case .outgoing:
            GranaTheme.Palette.red
        case .transfer:
            GranaTheme.Palette.tealDeep
        }
    }
}

private struct TableDivider: View {
    var body: some View {
        Rectangle()
            .fill(GranaTheme.Palette.line)
            .frame(height: 1)
            .padding(.leading, GranaTheme.Spacing.sm)
    }
}

private struct TableText: View {
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
            Text(primary)
                .font(GranaTheme.Typography.code)
                .foregroundStyle(GranaTheme.Palette.ink)
            Text(secondary)
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(GranaTheme.Palette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func tableRowContent() -> some View {
        padding(GranaTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func tableSurface() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
    }
}
