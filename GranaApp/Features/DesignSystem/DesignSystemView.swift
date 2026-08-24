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

    private let typographyTokens: [TypographyToken] = [
        TypographyToken(
            name: "hero",
            current: "System 34 black",
            prototype: "SF Pro Text 34 black",
            usage: "Título de página"
        ),
        TypographyToken(
            name: "title",
            current: "System 18 black",
            prototype: "SF Pro Text 18 black",
            usage: "Título de card"
        ),
        TypographyToken(
            name: "body",
            current: "System 15 semibold",
            prototype: "SF Pro Text 15 semibold",
            usage: "Texto principal"
        ),
        TypographyToken(name: "label", current: "System 13 bold", prototype: "SF Pro Text 13 bold", usage: "Rótulos"),
        TypographyToken(
            name: "number",
            current: "System digits",
            prototype: "Menlo/SF Mono digits",
            usage: "Valores monetários"
        ),
        TypographyToken(name: "token", current: "System mono", prototype: "Menlo/SF Mono", usage: "Tokens técnicos"),
        TypographyToken(
            name: "caption",
            current: "System 11 semibold",
            prototype: "SF Pro Text 11 semibold",
            usage: "Apoio e status"
        ),
    ]

    private let radiusTokens: [RadiusToken] = [
        RadiusToken(name: "control", radius: GranaTheme.Radius.control, usage: "Botões, inputs e badges"),
        RadiusToken(name: "card", radius: GranaTheme.Radius.card, usage: "Cards de conteúdo"),
        RadiusToken(name: "panel", radius: GranaTheme.Radius.panel, usage: "Mesmo valor do card", note: "igual a card"),
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
        ScrollView {
            standardSections
                .granaPagePadding()
        }
        .background(.clear)
        .navigationTitle("Design System")
        .navigationSubtitle("Tokens, superfícies e componentes base")
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 430), spacing: Spacing.lg, alignment: .top),
        ]
    }

    private var standardSections: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            DesignSystemCard(title: "Amostra tipográfica", content: {
                TypographyComparisonSample()
            })

            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.lg) {
                DesignSystemCard(title: "Tabela de tokens", content: {
                    TokenTable(tokens: paletteTokens)
                })

                DesignSystemCard(title: "Tabela de tipografia", content: {
                    TypographyTable(tokens: typographyTokens)
                })

                DesignSystemCard(title: "Tabela de raios", content: {
                    RadiusTable(tokens: radiusTokens)
                })

                DesignSystemCard(title: "Estados semânticos", content: {
                    SemanticStateTable(tokens: semanticTokens)
                })

                DesignSystemCard(title: "Camadas de profundidade das superfícies", content: {
                    SurfaceDepthLayers()
                })

                DesignSystemCard(title: "Botões", content: {
                    ButtonsShowcase()
                })

                DesignSystemCard(title: "Empty states", content: {
                    EmptyStatesShowcase()
                })
            }

            DesignSystemCard(title: "Exemplo de dashboard", content: {
                DashboardExample()
            })

            DesignSystemCard(title: "Exemplo de tabela de transações", content: {
                TransactionsTableExample()
            })

            DesignSystemCard(title: "Notice overlay", content: {
                NoticeOverlayShowcase(notices: sampleNotices)
            })
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
}

private enum DesignSystemTypography {
    static let hero = Font.system(size: 34, weight: .black)
    static let cardTitle = Font.system(size: 18, weight: .black)
    static let body = Font.system(size: 15, weight: .semibold)
    static let label = Font.system(size: 13, weight: .bold)
    static let metric = GranaTheme.Typography.number(size: 30, weight: .bold)
    static let mono = GranaTheme.Typography.token(size: 12, weight: .semibold)
    static let caption = Font.system(size: 11, weight: .semibold)
}

private struct TypographyComparisonSample: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Receitas no período")
                    .font(DesignSystemTypography.label)
                    .foregroundStyle(GranaTheme.Palette.muted)
                Text(
                    "A família de texto precisa ser confortável para leitura repetida em cards, tabelas e estados vazios."
                )
                .font(DesignSystemTypography.body)
                .foregroundStyle(GranaTheme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: Spacing.sm) {
                Text("R$ 12.400,90")
                    .font(DesignSystemTypography.metric)
                    .foregroundStyle(GranaTheme.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("balance.available")
                    .font(DesignSystemTypography.mono)
                    .foregroundStyle(GranaTheme.Palette.tealDeep)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(GranaTheme.Palette.teal.opacity(0.10), in: Capsule())
            }
            .frame(width: 240, alignment: .trailing)
        }
        .padding(14)
        .tableSurface()
    }
}

private struct DesignSystemCard<Content: View>: View {
    let title: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(DesignSystemTypography.cardTitle)
                .foregroundStyle(GranaTheme.Palette.ink)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
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

private struct TypographyToken: Identifiable {
    let name: String
    let current: String
    let prototype: String
    let usage: String

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
        VStack(spacing: 0) {
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
        HStack(spacing: Spacing.md) {
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
    let tokens: [TypographyToken]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: Spacing.md) {
                    Text("Aa")
                        .font(sampleFont(for: token.name))
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

    private func resolvedValue(for token: TypographyToken) -> String {
        token.name == "number" || token.name == "token" ? token.prototype : token.current
    }

    private func sampleFont(for name: String) -> Font {
        switch name {
        case "hero":
            return DesignSystemTypography.hero
        case "title":
            return DesignSystemTypography.cardTitle
        case "body":
            return DesignSystemTypography.body
        case "label":
            return DesignSystemTypography.label
        case "number":
            return DesignSystemTypography.metric
        case "token":
            return DesignSystemTypography.mono
        case "caption":
            return DesignSystemTypography.caption
        default:
            return DesignSystemTypography.body
        }
    }
}

private struct RadiusTable: View {
    let tokens: [RadiusToken]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: Spacing.md) {
                    RadiusPreview(radius: token.radius)
                    TableText(primary: token.name, secondary: "\(token.value) · \(token.usage)")

                    if let note = token.note {
                        Text(note)
                            .font(GranaTheme.Typography.token(size: 10, weight: .black))
                            .foregroundStyle(GranaTheme.Palette.tealDeep)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
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
        VStack(spacing: 0) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                HStack(spacing: Spacing.md) {
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(DesignSystemTypography.mono)
                .foregroundStyle(GranaTheme.Palette.ink)
            Text(subtitle)
                .font(DesignSystemTypography.caption)
                .foregroundStyle(GranaTheme.Palette.muted)
            Capsule()
                .fill(GranaTheme.Palette.teal)
                .frame(width: 160, height: 8)
            Capsule()
                .fill(GranaTheme.Palette.line)
                .frame(width: 220, height: 8)
        }
        .padding(18)
        .frame(width: width, height: 132, alignment: .topLeading)
        .granaSurface(prominence, cornerRadius: GranaTheme.Radius.card)
        .offset(offset)
    }
}

private struct ButtonsShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Button("Primário") {}
                    .buttonStyle(GranaPrimaryButtonStyle())
                Button("Secundário") {}
                    .buttonStyle(GranaSecondaryButtonStyle())
            }

            HStack(spacing: Spacing.sm) {
                Button {} label: {
                    Label("Salvar", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(GranaPrimaryButtonStyle())

                Button {} label: {
                    Label("Filtrar", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(GranaSecondaryButtonStyle())
            }

            HStack(spacing: Spacing.sm) {
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: Spacing.md)], spacing: Spacing.md) {
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: Spacing.md)], spacing: Spacing.md) {
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

            HStack(alignment: .top, spacing: Spacing.md) {
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon.systemImage)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(accent)
                }

                Text(title)
                    .font(DesignSystemTypography.label)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }

            Text(placeholder ? "—" : value.formatted(.currency(code: "BRL")))
                .font(DesignSystemTypography.metric)
                .foregroundStyle(placeholder ? GranaTheme.Palette.muted : GranaTheme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }
}

private struct MiniChartPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Fluxo do mês")
                .font(DesignSystemTypography.label)
                .foregroundStyle(GranaTheme.Palette.muted)

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                ForEach([0.42, 0.74, 0.56, 0.88, 0.63, 0.92], id: \.self) { value in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(GranaTheme.Palette.teal.opacity(0.24 + value * 0.42))
                        .frame(width: 28, height: 120 * value)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .bottomLeading)
        }
        .padding(16)
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Categorias")
                .font(DesignSystemTypography.label)
                .foregroundStyle(GranaTheme.Palette.muted)

            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(row.0)
                            .font(DesignSystemTypography.label)
                        Spacer()
                        Text(row.1)
                            .font(DesignSystemTypography.mono)
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
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }
}

private struct TransactionsTableExample: View {
    @State private var selectedRows: Set<String> = ["Mercado União", "Salário"]

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
        VStack(spacing: 0) {
            TransactionHeaderRow()
                .tableRowContent()
            TableDivider()

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                TransactionRow(
                    selection: binding(for: row.id),
                    institutionKind: row.institution,
                    description: row.description,
                    memo: row.memo,
                    date: Date(timeIntervalSince1970: 1_787_529_600),
                    amount: row.amount,
                    amountKind: row.amountKind,
                    status: row.status
                )
                .tableRowContent()

                if index < rows.count - 1 {
                    TableDivider()
                }
            }
        }
        .tableSurface()
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding {
            selectedRows.contains(id)
        } set: { isSelected in
            if isSelected {
                selectedRows.insert(id)
            } else {
                selectedRows.remove(id)
            }
        }
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
}

private struct TransactionHeaderRow: View {
    var body: some View {
        HStack {
            Text("Selecionar")
                .frame(width: 78, alignment: .leading)
            Text("Transação")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Status")
                .frame(width: 96, alignment: .leading)
            Text("Valor")
                .frame(width: 118, alignment: .trailing)
        }
        .font(DesignSystemTypography.mono)
        .foregroundStyle(GranaTheme.Palette.muted)
    }
}

private struct TableDivider: View {
    var body: some View {
        Rectangle()
            .fill(GranaTheme.Palette.line)
            .frame(height: 1)
            .padding(.leading, 12)
    }
}

private struct NoticeOverlayShowcase: View {
    let notices: [NoticeCenter.Notice]

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            ForEach(notices) { notice in
                NoticeCard(notice: notice) {}
                    .frame(maxWidth: 420)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
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
        VStack(alignment: .leading, spacing: 3) {
            Text(primary)
                .font(DesignSystemTypography.mono)
                .foregroundStyle(GranaTheme.Palette.ink)
            Text(secondary)
                .font(DesignSystemTypography.caption)
                .foregroundStyle(GranaTheme.Palette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func tableRowContent() -> some View {
        padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func tableSurface() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
    }
}
