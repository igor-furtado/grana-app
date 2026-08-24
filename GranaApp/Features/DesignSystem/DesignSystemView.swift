import SwiftUI

struct DesignSystemView: View {
    private let paletteTokens: [PaletteToken] = [
        PaletteToken(name: "background", value: "#f4f0e8", color: GranaTheme.Palette.background),
        PaletteToken(name: "backgroundStart", value: "#f8f3e8", color: GranaTheme.Palette.backgroundStart),
        PaletteToken(name: "backgroundEnd", value: "#edf4ef", color: GranaTheme.Palette.backgroundEnd),
        PaletteToken(name: "ink", value: "#17231f", color: GranaTheme.Palette.ink),
        PaletteToken(name: "muted", value: "ink 62%", color: GranaTheme.Palette.muted),
        PaletteToken(name: "line", value: "ink 13%", color: GranaTheme.Palette.line),
        PaletteToken(name: "paper", value: "#fffcf5", color: GranaTheme.Palette.paper),
        PaletteToken(name: "paperSolid", value: "#fffaf0", color: GranaTheme.Palette.paperSolid),
        PaletteToken(name: "teal", value: "#117a68", color: GranaTheme.Palette.teal),
        PaletteToken(name: "tealDeep", value: "#0c5f53", color: GranaTheme.Palette.tealDeep),
        PaletteToken(name: "green", value: "#147c56", color: GranaTheme.Palette.green),
        PaletteToken(name: "red", value: "#c9413a", color: GranaTheme.Palette.red),
        PaletteToken(name: "amber", value: "#d8912b", color: GranaTheme.Palette.amber),
        PaletteToken(name: "gold", value: "#edb85f", color: GranaTheme.Palette.gold),
        PaletteToken(name: "creamText", value: "#fff9ed", color: GranaTheme.Palette.creamText),
    ]

    private let radiusTokens: [RadiusToken] = [
        RadiusToken(name: "control", radius: GranaTheme.Radius.control, description: "menor canto do sistema"),
        RadiusToken(name: "card", radius: GranaTheme.Radius.card, description: "cards de conteúdo"),
        RadiusToken(
            name: "panel",
            radius: GranaTheme.Radius.panel,
            description: "mesmo raio de card",
            matchesCard: true
        ),
        RadiusToken(name: "rail", radius: GranaTheme.Radius.rail, description: "shell lateral"),
        RadiusToken(name: "hero", radius: GranaTheme.Radius.hero, description: "maior agrupamento visual"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                section("Paleta") {
                    VStack(spacing: 8) {
                        ForEach(paletteTokens) { token in
                            PaletteTokenRow(token: token)
                        }
                    }
                }

                section("Superfícies") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                        SurfaceSample(
                            title: "Shell glass",
                            subtitle: "Apenas shell, rail e chrome estrutural",
                            prominence: .glass
                        )
                        SurfaceSample(
                            title: "Content card",
                            subtitle: "Cards sem blur, com preenchimento e sombra baixa",
                            prominence: .subtle
                        )
                        SurfaceSample(
                            title: "Solid row",
                            subtitle: "Listas densas e tabelas, único papel com linha",
                            prominence: .solid
                        )
                    }
                }

                section("Componentes") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                        ComponentPanel("Buttons") {
                            HStack(spacing: 10) {
                                Button("Primário") {}
                                    .buttonStyle(GranaPrimaryButtonStyle())
                                Button("Secundário") {}
                                    .buttonStyle(GranaSecondaryButtonStyle())
                            }
                        }

                        ComponentPanel("MetricCard") {
                            MetricCard(
                                title: "Receitas no período",
                                value: Decimal(12400),
                                icon: .incomeFlow,
                                accent: .income
                            )
                        }

                        ComponentPanel("CategoryBadge") {
                            VStack(alignment: .leading, spacing: 10) {
                                CategoryBadge(category: sampleCategory, icon: .food)
                                CategoryBadge(category: sampleCategory, icon: .food, iconOnly: true)
                                    .help(sampleCategory.name)
                            }
                        }

                        ComponentPanel("EmptyStateView") {
                            EmptyStateView(
                                "Sem dados",
                                icon: .chartCategoryRanking,
                                description: "Estado vazio padronizado para telas e cards."
                            )
                            .scaleEffect(0.58)
                            .frame(height: 170)
                        }

                        ComponentPanel("NoticeOverlay") {
                            NoticeCard(notice: sampleNotice) {}
                        }
                    }
                }

                section("Raios") {
                    RadiusComparisonBoard(tokens: radiusTokens)
                }

                section("Estados semânticos") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        SemanticColorCard(title: "Receita", color: .income)
                        SemanticColorCard(title: "Despesa", color: .expense)
                        SemanticColorCard(title: "Transferência", color: .transfer)
                        SemanticColorCard(title: "Sucesso", color: .success)
                        SemanticColorCard(title: "Atenção", color: .warning)
                        SemanticColorCard(title: "Erro", color: .danger)
                    }
                }
            }
            .padding(20)
        }
        .background(.clear)
        .navigationTitle("Design System")
        .navigationSubtitle("GranaTheme e componentes reutilizáveis")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: AppIcon.sidebarDesignSystem.systemImage)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(GranaTheme.Palette.creamText)
                    .frame(width: 54, height: 54)
                    .background(
                        GranaTheme.brandGradient(),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("GranaTheme")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(GranaTheme.Palette.ink)
                    Text("Galeria interna para inspecionar tokens, superfícies e componentes base.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(GranaTheme.Palette.muted)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.hero)
    }

    private var sampleCategory: Category {
        Category(
            id: UUID(uuidString: "F0C77F80-2A21-44D8-9A0A-3D3503572E58")!,
            parentId: nil,
            name: "Mercado",
            kind: .expense,
            slug: "alimentacao",
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private var sampleNotice: NoticeCenter.Notice {
        NoticeCenter.Notice(
            kind: .success,
            title: "Importação concluída",
            message: "24 lançamentos revisados com sucesso.",
            createdAt: Date(timeIntervalSince1970: 0),
            actions: [
                NoticeCenter.Action(title: "Desfazer", role: .destructive) {},
            ],
            dismissAfter: .seconds(10)
        )
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(GranaTheme.Palette.ink)
            content()
        }
    }
}

private struct PaletteToken: Identifiable {
    let name: String
    let value: String
    let color: Color

    var id: String {
        name
    }
}

private struct RadiusToken: Identifiable {
    let name: String
    let radius: CGFloat
    let description: String
    var matchesCard = false

    var id: String {
        name
    }

    var value: String {
        "\(Int(radius)) pt"
    }
}

private struct PaletteTokenRow: View {
    let token: PaletteToken

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(token.color)
                .frame(width: 42, height: 42)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(GranaTheme.Palette.line, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(token.name)
                    .font(.system(size: 13, weight: .bold).monospaced())
                    .foregroundStyle(GranaTheme.Palette.ink)
                Text(token.value)
                    .font(.system(size: 12, weight: .semibold).monospaced())
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
    }
}

private struct SurfaceSample: View {
    let title: String
    let subtitle: String
    let prominence: GranaSurfaceProminence

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(GranaTheme.Palette.ink)
            Text(subtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GranaTheme.Palette.muted)
            HStack(spacing: 8) {
                Capsule().fill(GranaTheme.Palette.teal).frame(width: 68, height: 8)
                Capsule().fill(GranaTheme.Palette.gold).frame(width: 42, height: 8)
                Capsule().fill(GranaTheme.Palette.red).frame(width: 26, height: 8)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .granaSurface(prominence, cornerRadius: GranaTheme.Radius.card)
    }
}

private struct ComponentPanel<Content: View>: View {
    let title: String
    let content: Content

    init(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(GranaTheme.Palette.muted)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }
}

private struct RadiusComparisonBoard: View {
    let tokens: [RadiusToken]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(tokens) { token in
                HStack(spacing: 16) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: token.radius, style: .continuous)
                            .fill(GranaTheme.Palette.teal.opacity(0.14))
                            .frame(width: 142, height: 82)

                        RoundedRectangle(cornerRadius: token.radius, style: .continuous)
                            .strokeBorder(GranaTheme.Palette.teal.opacity(0.82), lineWidth: 1.4)
                            .frame(width: 142, height: 82)

                        Path { path in
                            let value = token.radius
                            path.move(to: CGPoint(x: value, y: 0))
                            path.addLine(to: CGPoint(x: value, y: value))
                            path.addLine(to: CGPoint(x: 0, y: value))
                        }
                        .stroke(
                            GranaTheme.Palette.tealDeep.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(token.name)
                                .font(.system(size: 12, weight: .black).monospaced())
                                .foregroundStyle(GranaTheme.Palette.ink)

                            if token.matchesCard {
                                RadiusBadge(text: "igual a card")
                            }
                        }

                        Text(token.value)
                            .font(.system(size: 12, weight: .semibold).monospaced())
                            .foregroundStyle(GranaTheme.Palette.muted)

                        Text(token.description)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(GranaTheme.Palette.muted)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
            }
        }
    }
}

private struct RadiusBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black).monospaced())
            .foregroundStyle(GranaTheme.Palette.tealDeep)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(GranaTheme.Palette.teal.opacity(0.10), in: Capsule())
    }
}

private struct SemanticColorCard: View {
    let title: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(GranaTheme.Palette.ink)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.control)
    }
}
