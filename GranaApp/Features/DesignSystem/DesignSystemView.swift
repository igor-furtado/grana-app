import SwiftUI
import AppUI

struct DesignSystemView: View {
    @State private var selectedSection: AtlasSection = .foundations

    private let paletteTokens: [TokenRowModel] = [
        TokenRowModel(name: "background", value: "#f4f0e8", swatch: AppUI.Theme.Palette.background),
        TokenRowModel(name: "backgroundStart", value: "#f8f3e8", swatch: AppUI.Theme.Palette.backgroundStart),
        TokenRowModel(name: "backgroundEnd", value: "#edf4ef", swatch: AppUI.Theme.Palette.backgroundEnd),
        TokenRowModel(name: "ink", value: "#17231f", swatch: AppUI.Theme.Palette.ink),
        TokenRowModel(name: "muted", value: "ink 62%", swatch: AppUI.Theme.Palette.muted),
        TokenRowModel(name: "line", value: "ink 13%", swatch: AppUI.Theme.Palette.line),
        TokenRowModel(name: "paper", value: "#fffcf5", swatch: AppUI.Theme.Palette.paper),
        TokenRowModel(name: "paperSolid", value: "#fffaf0", swatch: AppUI.Theme.Palette.paperSolid),
        TokenRowModel(name: "teal", value: "#117a68", swatch: AppUI.Theme.Palette.teal),
        TokenRowModel(name: "tealDeep", value: "#0c5f53", swatch: AppUI.Theme.Palette.tealDeep),
        TokenRowModel(name: "green", value: "#147c56", swatch: AppUI.Theme.Palette.green),
        TokenRowModel(name: "red", value: "#c9413a", swatch: AppUI.Theme.Palette.red),
        TokenRowModel(name: "amber", value: "#d8912b", swatch: AppUI.Theme.Palette.amber),
        TokenRowModel(name: "gold", value: "#edb85f", swatch: AppUI.Theme.Palette.gold),
        TokenRowModel(name: "creamText", value: "#fff9ed", swatch: AppUI.Theme.Palette.creamText),
    ]

    private let radiusTokens: [RadiusToken] = [
        RadiusToken(name: "control", radius: AppUI.Theme.Radius.control, usage: "Botões e controles compactos"),
        RadiusToken(name: "pill", radius: AppUI.Theme.Radius.pill, usage: "Inputs e badges"),
        RadiusToken(name: "card", radius: AppUI.Theme.Radius.card, usage: "Cards de conteúdo"),
        RadiusToken(name: "rail", radius: AppUI.Theme.Radius.rail, usage: "Shell lateral autenticado"),
        RadiusToken(name: "hero", radius: AppUI.Theme.Radius.hero, usage: "Header e agrupamentos amplos"),
    ]

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Layout.ScreenHeader(
                title: "Design System",
                subtitle: "Mapa vivo de tokens, componentes e exemplos para consultar o sistema sem perder a visão do todo."
            )

            ScrollViewReader { proxy in
                HStack(alignment: .top, spacing: AppUI.Theme.Spacing.md) {
                    AtlasNavigationCard(
                        selectedSection: $selectedSection,
                        sections: AtlasSection.allCases
                    ) { section in
                        scrollToSection(section, using: proxy)
                    }
                    .frame(width: 280)

                    ScrollView {
                        atlasSections
                            .padding(.bottom, AppUI.Theme.Spacing.lg)
                    }
                }
            }
        }
        .background(.clear)
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
    }

    private var atlasSections: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xl) {
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
                HStack(alignment: .top, spacing: AppUI.Theme.Spacing.md) {
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
                SpacingTable(tokens: AppUI.Theme.Spacing.tokens)
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
                VStack(spacing: AppUI.Theme.Spacing.sm) {
                    BasicTextFieldShowcase()
                    CurrencyFieldShowcase()
                    SelectorShowcase()
                    ToggleShowcase()
                    DatePickerShowcase()
                }
                .padding(AppUI.Theme.Spacing.md)
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

    private var visibleTypographyTokens: [AppUI.Theme.Typography.Token] {
        AppUI.Theme.Typography.tokens.filter { $0.family != .code }
    }

    private var textTypographyTokens: [AppUI.Theme.Typography.Token] {
        visibleTypographyTokens.filter { $0.family == .text }
    }

    private var moneyTypographyTokens: [AppUI.Theme.Typography.Token] {
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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
            Text(title)
                .font(AppUI.Theme.Typography.headline)
                .foregroundStyle(AppUI.Theme.Palette.ink)
            content()
        }
        .padding(.top, AppUI.Theme.Spacing.md)
        .padding(.trailing, AppUI.Theme.Spacing.xs)
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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
            DesignSystemSectionHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            )
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
            Text(eyebrow)
                .font(AppUI.Theme.Typography.caption1Emphasis)
                .foregroundStyle(AppUI.Theme.Palette.tealDeep)
            Text(title)
                .font(AppUI.Theme.Typography.title3)
                .foregroundStyle(AppUI.Theme.Palette.ink)
            Text(subtitle)
                .font(AppUI.Theme.Typography.subheadline)
                .foregroundStyle(AppUI.Theme.Palette.muted)
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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                    Text(row.0)
                        .font(AppUI.Theme.Typography.subheadlineEmphasis)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
                    Text(row.1)
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if row.0 != rows.last?.0 {
                    TableDivider()
                        .padding(.leading, AppUI.Theme.Spacing.none)
                }
            }
        }
        .padding(AppUI.Theme.Spacing.md)
        .tableSurface()
    }
}

private struct AtlasNavigationCard: View {
    @Binding var selectedSection: AtlasSection
    let sections: [AtlasSection]
    let onSelect: (AtlasSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
                Text("Mapa")
                    .font(AppUI.Theme.Typography.caption1Emphasis)
                    .foregroundStyle(AppUI.Theme.Palette.tealDeep)
                Text("Atlas da tela")
                    .font(AppUI.Theme.Typography.headline)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
                Text("Use como índice: cada bloco responde uma pergunta diferente sobre o sistema.")
                    .font(AppUI.Theme.Typography.caption1)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
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
        .padding(AppUI.Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.card)
    }
}

private struct AtlasNavigationRow: View {
    let section: AtlasSection
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppUI.Theme.Spacing.sm) {
            Circle()
                .fill(isSelected ? AppUI.Theme.Palette.teal : AppUI.Theme.Palette.line)
                .frame(width: 10, height: 10)
                .padding(.top, AppUI.Theme.Spacing.xxs)

            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                Text(section.eyebrow)
                    .font(AppUI.Theme.Typography.subheadlineEmphasis)
                    .foregroundStyle(isSelected ? AppUI.Theme.Palette.ink : AppUI.Theme.Palette.muted)
                Text(section.summary)
                    .font(AppUI.Theme.Typography.caption1)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: AppUI.Theme.Spacing.none)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.sm)
        .padding(.vertical, AppUI.Theme.Spacing.sm)
        .background(
            isSelected ? AppUI.Theme.Palette.teal.opacity(0.10) : AppUI.Theme.Palette.soft,
            in: RoundedRectangle(cornerRadius: AppUI.Theme.Radius.control, style: .continuous)
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
        VStack(spacing: AppUI.Theme.Spacing.none) {
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
        [GridItem(.adaptive(minimum: 150), spacing: AppUI.Theme.Spacing.sm)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            ForEach(tokens) { token in
                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(token.swatch)
                        .frame(height: 32)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AppUI.Theme.Palette.line, lineWidth: 1)
                        }

                    Text(token.name)
                        .font(AppUI.Theme.Typography.caption1Emphasis)
                        .foregroundStyle(AppUI.Theme.Palette.ink)

                    Text(token.value)
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(AppUI.Theme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tableSurface()
            }
        }
    }
}

private struct TokenTableRow: View {
    let token: TokenRowModel

    var body: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(token.swatch)
                .frame(width: 34, height: 34)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppUI.Theme.Palette.line, lineWidth: 1)
                }

            TableText(primary: token.name, secondary: token.value)
        }
        .tableRowContent()
    }
}

private struct TypographyColumn: View {
    let title: String
    let tokens: [AppUI.Theme.Typography.Token]

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            Text(title)
                .font(AppUI.Theme.Typography.caption1Emphasis)
                .foregroundStyle(AppUI.Theme.Palette.tealDeep)

            TypographyTable(tokens: tokens)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct TypographyTable: View {
    let tokens: [AppUI.Theme.Typography.Token]

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.none) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    Text(sampleText(for: token))
                        .font(token.font)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
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

    private func resolvedValue(for token: AppUI.Theme.Typography.Token) -> String {
        "\(token.value) · \(token.category)"
    }

    private func sampleText(for token: AppUI.Theme.Typography.Token) -> String {
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
        VStack(spacing: AppUI.Theme.Spacing.none) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    RadiusPreview(radius: token.radius)
                    TableText(primary: token.name, secondary: "\(token.value) · \(token.usage)")

                    if let note = token.note {
                        Text(note)
                            .font(AppUI.Theme.Typography.caption2Emphasis)
                            .foregroundStyle(AppUI.Theme.Palette.tealDeep)
                            .padding(.horizontal, AppUI.Theme.Spacing.xs)
                            .padding(.vertical, AppUI.Theme.Spacing.xxs)
                            .background(AppUI.Theme.Palette.teal.opacity(0.10), in: Capsule())
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
    let tokens: [AppUI.Theme.Spacing.Token]

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.none) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: AppUI.Theme.Spacing.sm) {
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
                .fill(AppUI.Theme.Palette.teal.opacity(0.82))
                .frame(width: 18, height: 28)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppUI.Theme.Palette.gold.opacity(0.82))
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
                .fill(AppUI.Theme.Palette.teal.opacity(0.14))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(AppUI.Theme.Palette.teal.opacity(0.82), lineWidth: 1.3)
            Path { path in
                path.move(to: CGPoint(x: radius, y: 0))
                path.addLine(to: CGPoint(x: radius, y: radius))
                path.addLine(to: CGPoint(x: 0, y: radius))
            }
            .stroke(
                AppUI.Theme.Palette.tealDeep.opacity(0.46),
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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xs) {
            Text(title)
                .font(AppUI.Theme.Typography.code)
                .foregroundStyle(AppUI.Theme.Palette.ink)
            Text(subtitle)
                .font(AppUI.Theme.Typography.caption1)
                .foregroundStyle(AppUI.Theme.Palette.muted)
            Capsule()
                .fill(AppUI.Theme.Palette.teal)
                .frame(width: 160, height: 8)
            Capsule()
                .fill(AppUI.Theme.Palette.line)
                .frame(width: 220, height: 8)
        }
        .padding(AppUI.Theme.Spacing.lg)
        .frame(width: width, height: 132, alignment: .topLeading)
        .granaSurface(prominence, cornerRadius: AppUI.Theme.Radius.card)
        .offset(offset)
    }
}

private struct ButtonsShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            HStack(spacing: AppUI.Theme.Spacing.xs) {
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

            HStack(spacing: AppUI.Theme.Spacing.xs) {
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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
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
    private let icons: [(AppUI.Icon, String)] = [
        (.sidebarDashboard, "Dashboard"),
        (.sidebarTransactions, "Transações"),
        (.add, "Adicionar"),
        (.success, "Sucesso"),
    ]

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.none) {
            ForEach(Array(icons.enumerated()), id: \.offset) { index, row in
                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    Image(systemName: row.0.systemImage)
                        .font(.system(size: AppUI.Theme.IconSize.medium, weight: .semibold))
                        .foregroundStyle(AppUI.Theme.Palette.tealDeep)
                        .frame(width: 32, height: 32)
                        .background(
                            AppUI.Theme.Palette.teal.opacity(0.10),
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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
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
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 210), spacing: AppUI.Theme.Spacing.sm)],
                spacing: AppUI.Theme.Spacing.sm
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

            HStack(alignment: .top, spacing: AppUI.Theme.Spacing.sm) {
                MiniChartPanel()
                CategoryRankingPanel()
            }
        }
    }
}

private struct TypographyMetricCard: View {
    let title: String
    let value: Decimal
    let icon: AppUI.Icon?
    let accent: Color
    var placeholder = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            HStack(spacing: AppUI.Theme.Spacing.xxs) {
                if let icon {
                    Image(systemName: icon.systemImage)
                        .font(.system(size: AppUI.Theme.IconSize.small, weight: .bold))
                        .foregroundStyle(accent)
                }

                Text(title)
                    .font(AppUI.Theme.Typography.subheadlineEmphasis)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }

            Text(placeholder ? "—" : value.formatted(.currency(code: "BRL")))
                .font(AppUI.Theme.Typography.moneyTitle2)
                .foregroundStyle(placeholder ? AppUI.Theme.Palette.muted : AppUI.Theme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(AppUI.Theme.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: AppUI.Theme.Radius.card)
    }
}

private struct MiniChartPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            Text("Fluxo do mês")
                .font(AppUI.Theme.Typography.subheadlineEmphasis)
                .foregroundStyle(AppUI.Theme.Palette.muted)

            HStack(alignment: .bottom, spacing: AppUI.Theme.Spacing.xs) {
                ForEach([0.42, 0.74, 0.56, 0.88, 0.63, 0.92], id: \.self) { value in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppUI.Theme.Palette.teal.opacity(0.24 + value * 0.42))
                        .frame(width: 28, height: 120 * value)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .bottomLeading)
        }
        .padding(AppUI.Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: AppUI.Theme.Radius.card)
    }
}

private struct CategoryRankingPanel: View {
    private let rows = [
        ("Mercado", "R$ 2.180", Color.expense, 0.86),
        ("Moradia", "R$ 1.950", Color.transfer, 0.76),
        ("Transporte", "R$ 740", Color.warning, 0.42),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.sm) {
            Text("Categorias")
                .font(AppUI.Theme.Typography.subheadlineEmphasis)
                .foregroundStyle(AppUI.Theme.Palette.muted)

            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                    HStack {
                        Text(row.0)
                            .font(AppUI.Theme.Typography.subheadlineEmphasis)
                        Spacer()
                        Text(row.1)
                            .font(AppUI.Theme.Typography.moneyFootnote)
                            .foregroundStyle(AppUI.Theme.Palette.muted)
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
        .padding(AppUI.Theme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .granaSurface(.subtle, cornerRadius: AppUI.Theme.Radius.card)
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
                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    InstitutionIcon(kind: row.institution, size: 24)
                    Text(row.institutionName)
                        .font(AppUI.Theme.Typography.subheadlineEmphasis)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
                }
            }
            .width(min: 160, ideal: 180, max: 220)

            TableColumn("Transação", value: \.description) { (row: TransactionPreview) in
                VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                    Text(row.description)
                        .font(AppUI.Theme.Typography.subheadlineEmphasis)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
                    Text(row.memo)
                        .font(AppUI.Theme.Typography.caption1)
                        .foregroundStyle(AppUI.Theme.Palette.muted)
                }
            }
            .width(min: 220, ideal: 280)

            TableColumn("Status", value: \.statusRank) { (row: TransactionPreview) in
                Text(row.statusLabel)
                    .font(AppUI.Theme.Typography.caption1Emphasis)
                    .foregroundStyle(row.statusColor)
            }
            .width(min: 92, ideal: 110, max: 132)

            TableColumn("Valor", value: \.amount) { (row: TransactionPreview) in
                Text(row.amount.formatted(.currency(code: "BRL")))
                    .font(AppUI.Theme.Typography.moneySubheadline)
                    .foregroundStyle(row.amountColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 120, ideal: 148, max: 180)
        } filterBar: {
            AppUI.TableFilterBar {
                AppUI.TextField(
                    label: "Transação",
                    text: $filterText,
                    placeholder: "Buscar descrição",
                    leadingSystemImage: "magnifyingglass",
                    showsClearButton: true,
                    font: AppUI.Theme.Typography.footnoteEmphasis,
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
        case .success?: AppUI.Theme.Palette.green
        case .warning?: AppUI.Theme.Palette.amber
        case .info?: AppUI.Theme.Palette.tealDeep
        case .neutral?: AppUI.Theme.Palette.muted
        case nil: AppUI.Theme.Palette.muted
        }
    }

    var amountColor: Color {
        switch amountKind {
        case .incoming:
            AppUI.Theme.Palette.green
        case .outgoing:
            AppUI.Theme.Palette.red
        case .transfer:
            AppUI.Theme.Palette.tealDeep
        }
    }
}

private struct TableDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppUI.Theme.Palette.line)
            .frame(height: 1)
            .padding(.leading, AppUI.Theme.Spacing.sm)
    }
}

private struct TableText: View {
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
            Text(primary)
                .font(AppUI.Theme.Typography.code)
                .foregroundStyle(AppUI.Theme.Palette.ink)
            Text(secondary)
                .font(AppUI.Theme.Typography.caption1)
                .foregroundStyle(AppUI.Theme.Palette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func tableRowContent() -> some View {
        padding(AppUI.Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func tableSurface() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.solid, cornerRadius: AppUI.Theme.Radius.control)
    }
}
