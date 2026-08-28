import SwiftUI

struct DesignSystemView: View {
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
                title: "Design System"
            )

            ScrollView {
                content
            }
        }
        .background(.clear)
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
    }

    private var detailColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 430), spacing: GranaTheme.Spacing.md, alignment: .top),
        ]
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxl) {
            heroSection
            foundationsSection
            componentsSection
            examplesSection
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

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
            DesignSystemHeroCard()

            HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                DesignSystemCard(
                    eyebrow: "Leitura",
                    title: "Amostra tipográfica",
                    subtitle: "Como texto, dinheiro e código convivem na mesma superfície."
                ) {
                    TypographyComparisonSample()
                }

                DesignSystemCard(
                    eyebrow: "Resumo",
                    title: "Princípios visuais",
                    subtitle: "O shell usa glass; conteúdo usa papel quente, tinta escura e acento teal."
                ) {
                    DesignSystemPrinciplesSummary()
                }
                .frame(width: 320)
            }
        }
    }

    private var foundationsSection: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            DesignSystemSectionHeader(
                eyebrow: "Fundamentos",
                title: "Tokens e superfícies",
                subtitle: "Paleta, semântica, tipografia, spacing, raios e profundidade visual."
            )

            HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                DesignSystemCard(
                    eyebrow: "Cor",
                    title: "Paleta e estados",
                    subtitle: "Marca, significado financeiro e feedback ficam separados."
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
                    subtitle: "Tokens textuais, monetários e de código."
                ) {
                    TypographyTable(tokens: GranaTheme.Typography.tokens)
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
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            DesignSystemSectionHeader(
                eyebrow: "Componentes",
                title: "Controles e feedback",
                subtitle: "Botões, estados vazios e notices no vocabulário final do app."
            )

            HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
                DesignSystemCard(
                    eyebrow: "Ações",
                    title: "Botões",
                    subtitle: "Primário e secundário no papel do app, sem cair em visual genérico."
                ) {
                    ButtonsShowcase()
                }
                .frame(width: 320)

                DesignSystemCard(
                    eyebrow: "Feedback",
                    title: "Notice overlay",
                    subtitle: "Toasts e mensagens flutuantes com contraste suficiente."
                ) {
                    NoticeOverlayShowcase(notices: sampleNotices)
                }
            }

            DesignSystemCard(
                eyebrow: "Vazio",
                title: "Empty states",
                subtitle: "Estados amplos e positivos, com tipografia e iconografia coerentes."
            ) {
                EmptyStatesShowcase()
            }
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            DesignSystemSectionHeader(
                eyebrow: "Aplicação",
                title: "Exemplos completos",
                subtitle: "Como os fundamentos escalam para dashboard e leitura de transações."
            )

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
                        "Painel quente, analítico e light-only. O objetivo aqui é validar matéria, contraste, densidade e hierarquia antes de espalhar padrões pelas features."
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
