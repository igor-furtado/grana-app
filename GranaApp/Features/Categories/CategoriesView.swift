import ComposableArchitecture
import Foundation
import SwiftUI

/// Inspeção read-only da taxonomia de categorias (raízes + subcategorias).
///
/// Categorias hoje são catálogo global read-only — usuário não cria nem edita.
/// Esta tela existe pra visibilidade: ver o que foi cadastrado, qual ícone tem
/// cada raiz, e quais subs caem sob ela. Quando o roadmap permitir edição,
/// esta vira a tela de CRUD.
///
/// **Decisão visual:** layout em dois painéis inspirado no app "SF Symbols"
/// da Apple. À esquerda, grid de cards uniformes (ícone destacado + nome) —
/// um item por categoria raiz, seccionados por `CategoryKind`. À direita,
/// inspector exibindo detalhes da categoria selecionada: ícone grande,
/// nome, kind e lista de subcategorias. Cards uniformes mantêm o ritmo
/// visual; subs ficam no inspector pra evitar cards de alturas variáveis.
///
/// Cor da categoria foi propositalmente omitida — decisão pendente sobre
/// como representá-la entra em outra iteração.
struct CategoriesView: View {
    @Bindable var store: StoreOf<CategoriesFeature>
    /// Persiste entre sessões — usuário que ocultou o inspector não quer
    /// vê-lo aparecer de novo na próxima vez que abre o app.
    @SceneStorage("CategoriesView.inspector") private var inspectorPresented: Bool = true

    var body: some View {
        CategoriesLoadedView(
            store: store,
            inspectorPresented: $inspectorPresented
        )
    }
}

private struct CategoriesLoadedView: View {
    @Bindable var store: StoreOf<CategoriesFeature>
    @Binding var inspectorPresented: Bool

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            header

            Group {
                if let loadErrorMessage = store.loadErrorMessage, store.categories.isEmpty {
                    EmptyStateView(
                        "Não foi possível carregar",
                        icon: .warning,
                        description: loadErrorMessage
                    )
                } else if store.isLoading, !store.hasLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.categories.isEmpty {
                    EmptyStateView(
                        "Nenhuma categoria disponível",
                        icon: .sidebarCategories,
                        description: "O backend não devolveu categorias para a sessão atual."
                    )
                } else {
                    grid
                }
            }
        }
        .inspector(isPresented: $inspectorPresented) {
            inspector
                .inspectorColumnWidth(min: 220, ideal: 280, max: 360)
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
        .task {
            await store.send(.task).finish()
        }
    }

    private var header: some View {
        AppUI.Layout.ScreenHeader(
            title: "Categorias",
            subtitle: "\(store.sortedRootCategories.count) categorias raiz no catálogo global"
        ) {
            HStack(spacing: GranaTheme.Spacing.sm) {
                Button {
                    Task {
                        await store.send(.refresh).finish()
                    }
                } label: {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                }
                .buttonStyle(GranaPrimaryButtonStyle())
                .disabled(store.isLoading)

                Button {
                    inspectorPresented.toggle()
                } label: {
                    Label("Detalhes", systemImage: AppIcon.inspectorToggle.systemImage)
                }
                .buttonStyle(GranaSecondaryButtonStyle())
                .help(inspectorPresented ? "Ocultar painel de detalhes" : "Mostrar painel de detalhes")
            }
        }
    }

    @ViewBuilder
    private var grid: some View {
        // Um único pass agrupando por kind, em vez de três `filter` separados.
        let byKind = Dictionary(grouping: store.categories, by: \.kind)
        let sections: [(CategoryKind, String, Color)] = [
            (.income, "Receitas", .income),
            (.expense, "Despesas", .expense),
            (.transfer, "Transferências", .transfer),
        ]

        ScrollView {
            LazyVStack(alignment: .leading, spacing: GranaTheme.Spacing.xxl) {
                ForEach(sections, id: \.0) { kind, title, accent in
                    let groups = makeGroups(from: byKind[kind] ?? [])
                    if !groups.isEmpty {
                        kindSection(title: title, accent: accent, groups: groups)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Seção de um kind: cabeçalho com bolinha de cor + título + contagem,
    /// e um `LazyVGrid` adaptativo de cards uniformes.
    private func kindSection(title: String, accent: Color, groups: [CategoryGroup]) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
            HStack(spacing: GranaTheme.Spacing.xs) {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(GranaTheme.Typography.title3)
                Text("(\(groups.count))")
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Self.gridColumns, alignment: .leading, spacing: GranaTheme.Spacing.sm) {
                ForEach(groups) { group in
                    CategoryCard(
                        group: group,
                        isSelected: store.selectedId == group.id,
                        onTap: { store.send(.select(group.id)) }
                    )
                }
            }
        }
    }

    private static let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 150), spacing: GranaTheme.Spacing.sm, alignment: .top),
    ]

    @ViewBuilder
    private var inspector: some View {
        if let group = selectedGroup {
            CategoryInspector(group: group)
        } else {
            inspectorPlaceholder
        }
    }

    private var inspectorPlaceholder: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            Image(systemName: AppIcon.sidebarCategories.systemImage)
                .font(.system(size: GranaTheme.IconSize.large))
                .foregroundStyle(.tertiary)
            Text("Selecione uma categoria")
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// `CategoryGroup` referente à seleção atual. Reusa `makeGroups` pra
    /// manter uma única fonte de verdade pra "como se monta um grupo"
    /// (filtragem de raiz + ordenação das subs). Recomputa quando categorias
    /// ou seleção mudam — barato, lista pequena.
    private var selectedGroup: CategoryGroup? {
        guard let selectedId = store.selectedId else { return nil }
        return makeGroups(from: store.categories).first { $0.id == selectedId }
    }

    /// Achata a hierarquia raiz→subs (já filtradas por kind pelo caller) numa
    /// lista de `CategoryGroup`. Pré-agrupar subs por `parentId` evita O(n²).
    private func makeGroups(from inKind: [Category]) -> [CategoryGroup] {
        let roots = inKind
            .filter { $0.parentId == nil }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

        let subsByParent = Dictionary(
            grouping: inKind.compactMap { category -> (UUID, Category)? in
                guard let parentId = category.parentId else { return nil }
                return (parentId, category)
            },
            by: { pair in pair.0 }
        )

        return roots.map { root in
            let subs = (subsByParent[root.id] ?? [])
                .map { $0.1 }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            return CategoryGroup(root: root, subs: subs)
        }
    }
}

/// Raiz + subcategorias dela (já ordenadas alfabeticamente). Encapsula pra
/// evitar consumidores recomputarem/ordenarem subs a cada render.
private struct CategoryGroup: Identifiable {
    let root: Category
    let subs: [Category]

    var id: UUID {
        root.id
    }
}

/// Card uniforme de uma categoria raiz. Altura fixa pra manter ritmo visual
/// da grid — subs vivem no inspector lateral, não no card. Ícone domina
/// (~36pt), nome em peso médio abaixo, centralizado. Sem cor da categoria
/// por ora (decisão pendente). Estado selecionado ganha borda accent.
private struct CategoryCard: View {
    let group: CategoryGroup
    let isSelected: Bool
    let onTap: () -> Void

    private static let cardHeight: CGFloat = 124
    /// Corner radius pareado ao default visual do `GroupBox` no macOS (~8pt
    /// hoje). Mantemos em constante pra que o overlay de seleção case com a
    /// curva da caixa — se a Apple mudar o radius, ajusta aqui.
    private static let selectionCornerRadius: CGFloat = 8

    var body: some View {
        // `Button` em vez de `onTapGesture`: HIG quer área clicável como botão
        // (focus ring nativo, Space/Enter, VoiceOver). `GroupBox` dentro do
        // botão dá o agrupamento visual padrão do sistema; seleção é
        // sinalizada por borda accent overlay (mesmo padrão usado pelo app
        // SF Symbols pra tile selecionada).
        Button(action: onTap) {
            GroupBox {
                VStack(spacing: GranaTheme.Spacing.sm) {
                    iconView
                        .frame(maxWidth: .infinity)

                    Text(group.root.name)
                        .font(GranaTheme.Typography.calloutEmphasis)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(height: Self.cardHeight)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Self.selectionCornerRadius, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .opacity(isSelected ? 1 : 0)
            )
            .contentShape(Rectangle())
        }
        // `.plain` é estrutural: o tile inteiro (GroupBox + overlay de
        // seleção) é o visual. Sem `.plain` o sistema desenha um push
        // button por cima do GroupBox e o card vira "botão dentro de
        // botão".
        .buttonStyle(.plain)
        .accessibilityLabel(group.root.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = group.root.icon {
            Image(systemName: icon.systemImage)
                .font(.system(size: GranaTheme.IconSize.large, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(icon.color.gradient)
        } else {
            Image(systemName: AppIcon.warning.systemImage)
                .font(.system(size: GranaTheme.IconSize.large, weight: .regular))
                .foregroundStyle(.tertiary)
        }
    }
}

/// Painel direito de detalhes. Espelha a estrutura do inspector do app SF
/// Symbols: preview grande do ícone no topo, nome, e seções de metadados
/// abaixo — aqui, kind + lista de subcategorias.
private struct CategoryInspector: View {
    let group: CategoryGroup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                iconHero

                VStack(alignment: .center, spacing: GranaTheme.Spacing.xxs) {
                    Text(group.root.name)
                        .font(GranaTheme.Typography.title3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    kindBadge
                        .frame(maxWidth: .infinity)
                }

                Divider()

                subsSection
            }
            .padding(GranaTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var iconHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )

            if let icon = group.root.icon {
                Image(systemName: icon.systemImage)
                    .font(.system(size: GranaTheme.IconSize.hero, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(icon.color.gradient)
            } else {
                Image(systemName: AppIcon.warning.systemImage)
                    .font(.system(size: GranaTheme.IconSize.hero, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var kindBadge: some View {
        let (label, color) = kindMeta
        HStack(spacing: GranaTheme.Spacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(.secondary)
        }
    }

    private var kindMeta: (String, Color) {
        switch group.root.kind {
        case .income: ("Receita", .income)
        case .expense: ("Despesa", .expense)
        case .transfer: ("Transferência", .transfer)
        }
    }

    /// Usa `GroupBox` em vez de `RoundedRectangle` manual: dá agrupamento
    /// visual padrão do sistema (label + material backdrop), encaixa bem
    /// dentro do pane do `.inspector()` (que Apple desenhou pra hospedar
    /// exatamente esse tipo de bloco). Mesmo container é usado por
    /// `MetricCard` e pelo `CategoryCard` deste arquivo — sinal do "kind"
    /// migrou de tint de fundo pra accent no ícone.
    private var subsSection: some View {
        GroupBox {
            if group.subs.isEmpty {
                Text("Sem subcategorias cadastradas")
                    .font(GranaTheme.Typography.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                    ForEach(group.subs) { sub in
                        Text(sub.name)
                            .font(GranaTheme.Typography.subheadline)
                            .foregroundStyle(.primary.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } label: {
            HStack(spacing: GranaTheme.Spacing.xxs) {
                Text("Subcategorias")
                Text("(\(group.subs.count))")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
