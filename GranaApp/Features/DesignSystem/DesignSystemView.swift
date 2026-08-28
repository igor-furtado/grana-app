import SwiftUI

struct DesignSystemView: View {
    @State private var selectedSection: AtlasSection = .overview

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
        RadiusToken(name: "control", radius: GranaTheme.Radius.control, usage: "Botões, inputs e badges"),
        RadiusToken(name: "card", radius: GranaTheme.Radius.card, usage: "Cards de conteúdo"),
        RadiusToken(name: "rail", radius: GranaTheme.Radius.rail, usage: "Shell lateral autenticado"),
        RadiusToken(name: "hero", radius: GranaTheme.Radius.hero, usage: "Header e agrupamentos amplos"),
    ]

    private let semanticTokens: [SemanticToken] = [
        SemanticToken(name: "income", label: "Receita", usage: "Entrada financeira", color: .income),
        SemanticToken(name: "expense", label: "Despesa", usage: "Saída financeira", color: .expense),
        SemanticToken(name: "transfer", label: "Transferência", usage: "Movimento entre contas", color: .transfer),
        SemanticToken(name: "success", label: "Sucesso", usage: "Confirmação", color: .success),
        SemanticToken(name: "warning", label: "Atenção", usage: "Revisão ou alerta", color: .warning),
        SemanticToken(name: "danger", label: "Erro", usage: "Falha ou destrutivo", color: .danger),
    ]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            FeatureScreenHeader(
                title: "Design System",
                subtitle: "Mapa vivo de tokens, componentes e exemplos para consultar o sistema sem perder a visão do todo."
            )

            ScrollViewReader { proxy in
                ScrollView {
                    content(scrollProxy: proxy)
                        .padding(.bottom, GranaTheme.Spacing.lg)
                }
            }
        }
        .background(.clear)
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
    }

    private var detailColumns: [GridItem] { [GridItem(.adaptive(minimum: 430), spacing: GranaTheme.Spacing.md, alignment: .top)] }

    private var atlasColumns: [GridItem] { [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: GranaTheme.Spacing.md, alignment: .top)] }

    private func content(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxl) {
            DesignSystemHeroCard()
            ViewThatFits(in: .horizontal) {
                atlasWideLayout(scrollProxy: scrollProxy)
                atlasCompactLayout(scrollProxy: scrollProxy)
            }
        }
    }

    private var sampleNotices: [NoticeCenter.Notice] {
        [
            NoticeCenter.Notice(
                kind: .success,
                title: "Importação concluída",
                message: "24 lançamentos revisados com sucesso.",
                createdAt: Date(timeIntervalSince1970: 0),
                actions: [NoticeCenter.Action(title: "Desfazer", role: .destructive) {}],
                dismissAfter: .seconds(10)
            ),
            NoticeCenter.Notice(
                kind: .error,
                title: "Falha ao salvar",
                message: "Confira a conexão e tente novamente.",
                createdAt: Date(timeIntervalSince1970: 0),
                actions: [],
                dismissAfter: .seconds(10)
            ),
        ]
    }

    private func atlasWideLayout(scrollProxy: ScrollViewProxy) -> some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
            AtlasNavigationCard(
                selectedSection: $selectedSection,
                sections: AtlasSection.allCases
            ) { section in
                scrollToSection(section, using: scrollProxy)
            }
            .frame(width: 280)

            atlasSections
        }
    }

    private func atlasCompactLayout(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            AtlasNavigationCard(
                selectedSection: $selectedSection,
                sections: AtlasSection.allCases
            ) { section in
                scrollToSection(section, using: scrollProxy)
            }

            atlasSections
        }
    }

    private var atlasSections: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xl) {
            overviewSection
                .id(AtlasSection.overview)
            foundationsSection
                .id(AtlasSection.foundations)
            componentsSection
                .id(AtlasSection.components)
            examplesSection
                .id(AtlasSection.examples)
        }
    }

    private var overviewSection: some View {
        AtlasSectionContainer(
            eyebrow: AtlasSection.overview.eyebrow,
            title: "Comece pelo mapa, depois aprofunde onde precisar.",
            subtitle: """
            A tela funciona melhor quando deixa claro como consultar o sistema:
            primeiro visão geral, depois biblioteca de fundamentos, depois componentes
            e por fim prova em telas reais.
            """
        ) {
            LazyVGrid(columns: atlasColumns, alignment: .leading, spacing: GranaTheme.Spacing.md) {
                DesignSystemCard(
                    eyebrow: "Fluxo",
                    title: "Como ler esta tela",
                    subtitle: "Um nível de informação por bloco para evitar uma parede homogênea de showcases."
                ) {
                    AtlasReadingPath()
                }
                DesignSystemCard(
                    eyebrow: "Resumo",
                    title: "Princípios visuais",
                    subtitle: "O shell usa glass; o conteúdo usa papel quente, hierarquia tipográfica e semântica explícita."
                ) {
                    DesignSystemPrinciplesSummary()
                }
                DesignSystemCard(
                    eyebrow: "Amostra",
                    title: "Texto, dinheiro e código",
                    subtitle: "Uma prévia rápida da convivência entre estilos antes de abrir as tabelas completas."
                ) {
                    TypographyComparisonSample()
                }
            }
        }
    }

    private var foundationsSection: some View {
        AtlasSectionContainer(
            eyebrow: AtlasSection.foundations.eyebrow,
            title: "Fundamentos como biblioteca consultável.",
            subtitle: "Paleta, semântica, matéria visual, tipografia, spacing e raios ficam agrupados por função para consulta rápida."
        ) {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                DesignSystemCard(
                    eyebrow: "Cor",
                    title: "Paleta e estados",
                    subtitle: "Marca, significado financeiro e feedback continuam separados."
                ) {
                    VStack(spacing: GranaTheme.Spacing.md) {
                        TokenTable(tokens: paletteTokens)
                        SemanticStateTable(tokens: semanticTokens)
                    }
                }
                DesignSystemCard(
                    eyebrow: "Matéria",
                    title: "Camadas de profundidade",
                    subtitle: "Glass para shell; subtle e solid para leitura analítica."
                ) {
                    SurfaceDepthLayers()
                }
                .frame(width: 360)
            }

            LazyVGrid(columns: detailColumns, alignment: .leading, spacing: GranaTheme.Spacing.md) {
                DesignSystemCard(
                    eyebrow: "Tipo",
                    title: "Escala tipográfica",
                    subtitle: "Tokens textuais, monetários e de código com amostra direta de uso."
                ) {
                    VStack(spacing: GranaTheme.Spacing.md) {
                        TypographyComparisonSample()
                        TypographyTable(tokens: GranaTheme.Typography.tokens)
                    }
                }
                DesignSystemCard(
                    eyebrow: "Ritmo",
                    title: "Spacing",
                    subtitle: "A respiração padrão de cards, tabelas e grupos."
                ) {
                    SpacingTable(tokens: GranaTheme.Spacing.tokens)
                }

                DesignSystemCard(
                    eyebrow: "Forma",
                    title: "Raios",
                    subtitle: "Escala de curvatura para controles, cards, rail e hero."
                ) {
                    RadiusTable(tokens: radiusTokens)
                }
            }
        }
    }

    private var componentsSection: some View {
        AtlasSectionContainer(
            eyebrow: AtlasSection.components.eyebrow,
            title: "Componentes organizados por responsabilidade.",
            subtitle: "Em vez de um inventário linear, a leitura separa estrutura, ações e feedback para mostrar o papel de cada bloco no sistema."
        ) {
            LazyVGrid(columns: atlasColumns, alignment: .leading, spacing: GranaTheme.Spacing.md) {
                DesignSystemCard(
                    eyebrow: "Estrutura",
                    title: "Shell e leitura",
                    subtitle: "Os componentes estruturais definem enquadramento, não disputam atenção com os showcases."
                ) {
                    AtlasStructureSummary()
                }
                DesignSystemCard(
                    eyebrow: "Ações",
                    title: "Botões e affordance",
                    subtitle: "Primário e secundário no papel do app, sem cair em visual genérico."
                ) {
                    ButtonsShowcase()
                }

                DesignSystemCard(
                    eyebrow: "Feedback",
                    title: "Notices e estados vazios",
                    subtitle: "Mensagens temporárias e ausência de dados precisam manter contraste e direção."
                ) {
                    VStack(spacing: GranaTheme.Spacing.md) {
                        NoticeOverlayShowcase(notices: sampleNotices)
                        EmptyStatesShowcase()
                    }
                }
            }
        }
    }

    private var examplesSection: some View {
        AtlasSectionContainer(
            eyebrow: AtlasSection.examples.eyebrow,
            title: "Exemplos no fim como prova de escala.",
            subtitle: "Dashboard e transações fecham a leitura mostrando como os fundamentos se comportam em telas reais e mais densas."
        ) {
            DesignSystemCard(
                eyebrow: "Painel",
                title: "Dashboard",
                subtitle: "Cards, gráfico e ranking em uma composição de análise financeira."
            ) {
                DashboardExample()
            }

            DesignSystemCard(
                eyebrow: "Tabela",
                title: "Transações",
                subtitle: "Densidade, hierarquia e legibilidade em uma lista operacional."
            ) {
                TransactionsTableExample()
            }
        }
    }

    private func scrollToSection(_ section: AtlasSection, using proxy: ScrollViewProxy) {
        selectedSection = section
        withAnimation(.easeInOut(duration: 0.22)) {
            proxy.scrollTo(section, anchor: .top)
        }
    }
}

private struct TypographyComparisonSample: View {
    var body: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                Text("Receitas no período")
                    .font(GranaTheme.Typography.subheadlineEmphasis)
                    .foregroundStyle(GranaTheme.Palette.muted)
                Text(
                    "A família de texto precisa ser confortável para leitura repetida em cards, tabelas e estados vazios."
                )
                .font(GranaTheme.Typography.body)
                .foregroundStyle(GranaTheme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: GranaTheme.Spacing.xs) {
                Text("R$ 12.400,90")
                    .font(GranaTheme.Typography.moneyTitle2)
                    .foregroundStyle(GranaTheme.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("balance.available")
                    .font(GranaTheme.Typography.code)
                    .foregroundStyle(GranaTheme.Palette.tealDeep)
                    .padding(.horizontal, GranaTheme.Spacing.xs)
                    .padding(.vertical, GranaTheme.Spacing.xxs)
                    .background(GranaTheme.Palette.teal.opacity(0.10), in: Capsule())
            }
            .frame(width: 240, alignment: .trailing)
        }
        .padding(GranaTheme.Spacing.md)
        .tableSurface()
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
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                if let eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow)
                        .font(GranaTheme.Typography.caption1Emphasis)
                        .foregroundStyle(GranaTheme.Palette.tealDeep)
                }
                Text(title)
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.ink)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(GranaTheme.Typography.caption1)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }
}

private struct DesignSystemHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
            HStack(alignment: .top, spacing: GranaTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                    Text("Design System")
                        .font(GranaTheme.Typography.largeTitle)
                        .foregroundStyle(GranaTheme.Palette.ink)
                    Text(
                        """
                        Mapa vivo do sistema visual. A leitura começa pelo panorama,
                        aprofunda fundamentos e componentes em blocos consultáveis e
                        termina com provas em telas reais.
                        """
                    )
                    .font(GranaTheme.Typography.body)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: GranaTheme.Spacing.lg)
                VStack(alignment: .trailing, spacing: GranaTheme.Spacing.sm) {
                    Text("ink -> teal")
                        .font(GranaTheme.Typography.code)
                        .foregroundStyle(GranaTheme.Palette.tealDeep)
                    LinearGradient(
                        colors: [
                            GranaTheme.Palette.ink,
                            GranaTheme.Palette.teal,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 180, height: 14)
                    .clipShape(Capsule(style: .continuous))
                }
            }
            HStack(spacing: GranaTheme.Spacing.sm) {
                HeroBadge(label: "Light only", tint: GranaTheme.Palette.gold)
                HeroBadge(label: "Glass no shell", tint: GranaTheme.Palette.teal)
                HeroBadge(label: "Paper no conteúdo", tint: GranaTheme.Palette.green)
                HeroBadge(label: "Teal != receita", tint: GranaTheme.Palette.red)
            }
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 200), spacing: GranaTheme.Spacing.sm),
                ],
                spacing: GranaTheme.Spacing.sm
            ) {
                AtlasHighlightCard(
                    eyebrow: "Mapa",
                    value: "4 camadas",
                    subtitle: "Visão geral, fundamentos, componentes e aplicação."
                )
                AtlasHighlightCard(
                    eyebrow: "Meta",
                    value: "Consulta curta",
                    subtitle: "Cada grupo responde uma pergunta clara sobre o sistema."
                )
                AtlasHighlightCard(
                    eyebrow: "Risco evitado",
                    value: "Mesmo peso visual",
                    subtitle: "Showcases não entram todos na mesma altura de leitura."
                )
                AtlasHighlightCard(
                    eyebrow: "Decisão",
                    value: "Atlas",
                    subtitle: "Índice, panorama e blocos por função."
                )
            }
        }
        .padding(GranaTheme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    GranaTheme.Palette.paper.opacity(0.98),
                    GranaTheme.Palette.teal.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                .stroke(GranaTheme.Palette.line, lineWidth: 1)
        }
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
        .padding(GranaTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
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

private struct AtlasReadingPath: View {
    private let rows = [
        ("1", "Panorama", "Entender rapidamente o que a tela cobre e em que ordem consultar."),
        ("2", "Fundamentos", "Localizar tokens e regras sem ter que percorrer exemplos completos."),
        ("3", "Componentes", "Ver estrutura, ações e feedback com papéis claros."),
        ("4", "Aplicação", "Confirmar densidade e consistência em dashboard e transações."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.sm) {
            ForEach(rows, id: \.0) { row in
                HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                    Text(row.0)
                        .font(GranaTheme.Typography.footnoteEmphasis)
                        .foregroundStyle(GranaTheme.Palette.creamText)
                        .frame(width: 24, height: 24)
                        .background(
                            LinearGradient(
                                colors: [GranaTheme.Palette.ink, GranaTheme.Palette.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )

                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                        Text(row.1)
                            .font(GranaTheme.Typography.subheadlineEmphasis)
                            .foregroundStyle(GranaTheme.Palette.ink)
                        Text(row.2)
                            .font(GranaTheme.Typography.caption1)
                            .foregroundStyle(GranaTheme.Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

private struct AtlasStructureSummary: View {
    private let rows = [
        ("FeatureScreenHeader", "Enquadra a tela e declara o contexto antes do catálogo."),
        ("Mapa de leitura", "Permite consulta não linear sem perder a estrutura global."),
        ("DesignSystemCard", "Agrupa amostras e regras sem virar uma grade homogênea."),
        ("Section container", "Separa visão geral, fundamentos, componentes e aplicação."),
    ]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            ForEach(Array(rows.enumerated()), id: \.element.0) { index, row in
                HStack(spacing: GranaTheme.Spacing.sm) {
                    TableText(primary: row.0, secondary: row.1)
                }
                .tableRowContent()
                if index < rows.count - 1 {
                    TableDivider()
                }
            }
        }
        .tableSurface()
    }
}

private struct AtlasHighlightCard: View {
    let eyebrow: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
            Text(eyebrow)
                .font(GranaTheme.Typography.caption1Emphasis)
                .foregroundStyle(GranaTheme.Palette.tealDeep)
            Text(value)
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)
            Text(subtitle)
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(GranaTheme.Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GranaTheme.Palette.paper.opacity(0.80),
            in: RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
                .stroke(GranaTheme.Palette.line, lineWidth: 1)
        }
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
    case overview
    case foundations
    case components
    case examples

    var id: String {
        rawValue
    }

    var eyebrow: String {
        switch self {
        case .overview:
            "Visão geral"
        case .foundations:
            "Fundamentos"
        case .components:
            "Componentes"
        case .examples:
            "Aplicação"
        }
    }

    var summary: String {
        switch self {
        case .overview:
            "Como usar a tela e em que ordem ler."
        case .foundations:
            "Tokens, superfícies, tipografia, spacing e raios."
        case .components:
            "Estrutura, ações, feedback e estados vazios."
        case .examples:
            "Dashboard e transações como prova final."
        }
    }
}

private struct HeroBadge: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(GranaTheme.Typography.caption1Emphasis)
            .foregroundStyle(tint)
            .padding(.horizontal, GranaTheme.Spacing.sm)
            .padding(.vertical, GranaTheme.Spacing.xs)
            .background(tint.opacity(0.12), in: Capsule(style: .continuous))
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

private struct SemanticToken: Identifiable {
    let name: String
    let label: String
    let usage: String
    let color: Color

    var id: String {
        name
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

private struct TypographyTable: View {
    let tokens: [GranaTheme.Typography.Token]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: GranaTheme.Spacing.sm) {
                    Text("Aa")
                        .font(token.font)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .frame(width: 56, alignment: .leading)

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

private struct SemanticStateTable: View {
    let tokens: [SemanticToken]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: GranaTheme.Spacing.md) {
                    Circle()
                        .fill(token.color)
                        .frame(width: 22, height: 22)
                    TableText(primary: token.name, secondary: "\(token.label) · \(token.usage)")
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
            }

            HStack(spacing: GranaTheme.Spacing.xs) {
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

private struct EmptyStatesShowcase: View {
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 220), spacing: GranaTheme.Spacing.sm)],
            spacing: GranaTheme.Spacing.sm
        ) {
            EmptyStateView(
                "Sem transações",
                icon: .sidebarTransactions,
                description: "Quando não há registros para o filtro atual."
            )
            .frame(minHeight: 190)

            EmptyStateView(
                "Nada para revisar",
                icon: .success,
                description: "Estado positivo após finalizar uma fila."
            )
            .frame(minHeight: 190)
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
        GranaTable(filteredRows, selection: $selectedRows, sortOrder: $sortOrder) {
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
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                    Text("Transação")
                        .font(GranaTheme.Typography.caption2Emphasis)
                        .foregroundStyle(GranaTheme.Palette.muted)

                    HStack(spacing: GranaTheme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                            .foregroundStyle(GranaTheme.Palette.tealDeep)

                        TextField("Buscar descrição", text: $filterText)
                            .textFieldStyle(.plain)
                            .font(GranaTheme.Typography.footnoteEmphasis)

                        if !filterText.isEmpty {
                            Button {
                                filterText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(GranaTheme.Palette.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, GranaTheme.Spacing.sm)
                    .frame(width: 240, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(GranaTheme.Palette.paper.opacity(0.92))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(GranaTheme.Palette.line, lineWidth: 1)
                    }
                }
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

private struct NoticeOverlayShowcase: View {
    let notices: [NoticeCenter.Notice]

    var body: some View {
        VStack(alignment: .trailing, spacing: GranaTheme.Spacing.xs) {
            ForEach(notices) { notice in
                NoticeCard(notice: notice) {}
                    .frame(maxWidth: 420)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(GranaTheme.Spacing.md)
        .background(
            GranaTheme.Palette.soft,
            in: RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous)
        )
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
