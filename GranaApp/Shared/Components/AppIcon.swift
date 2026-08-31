import SwiftUI

/// Catálogo central de SF Symbols usados como **chrome de UI** (sidebar nav,
/// toolbars, empty states, métricas, feedback de status). Ícones de **domínio**
/// vivem nos enums das próprias entidades — `CategoryIcon` (categoria),
/// `InstitutionKind` (instituição).
///
/// **Por que centralizar:** strings cruas de SF Symbol espalhadas pelas Views
/// criam três problemas — typo silencioso (só descobre em runtime, ícone some),
/// duplicação semântica (5 lugares usam "exclamationmark.triangle.fill" pra
/// significar "warning"), e troca de símbolo vira find-and-replace frágil.
/// O enum corrige tudo: compilador valida, intenção fica nomeada, troca = uma
/// linha no switch.
///
/// **Nomeação por intenção, não pelo símbolo.** Caso é `success`, não
/// `checkmarkCircle` — se amanhã trocarmos pro `checkmark.seal.fill`, o nome
/// do caso continua certo. Mesmo princípio do `CategoryIcon`.
public enum Icon {
    // MARK: - Ações

    case add
    case edit
    case delete
    case undo
    case importFile
    case archive
    case unarchive
    case sort
    case inspectorToggle
    case more
    case copy
    case close
    case signOut

    // MARK: - Métricas / dashboard

    case balance
    case expenseFlow
    case incomeFlow
    case netResult

    // MARK: - Empty states de charts do dashboard

    //
    // Um ícone por chart, escolhido pelo eixo semântico do gráfico — assim
    // três cards de chart vazios lado a lado mantêm pistas visuais distintas
    // do que cada um exibiria com dados.

    case chartCategoryRanking
    case chartIncomeExpense
    case chartWeekday

    // MARK: - Feedback de status

    case success
    case warning
    case error
    case info
    case unknown
    case completedSeal
    case invalidDate
    case invalidAmount

    // MARK: - Sidebar / Seções

    case sidebarDashboard
    case sidebarTransactions
    case sidebarCreditCards
    case sidebarAccounts
    case sidebarImport
    case sidebarCategories
    case sidebarInstitutions
    case sidebarDesignSystem
    case sidebarProfile

    /// Nome do SF Symbol, pra `Image(systemName:)` ou `Label(_:systemImage:)`.
    public var systemImage: String {
        switch self {
        // Ações
        case .add: "plus"
        case .edit: "pencil"
        case .delete: "trash"
        case .undo: "arrow.uturn.backward"
        case .importFile: "square.and.arrow.down"
        case .archive: "archivebox"
        case .unarchive: "tray.and.arrow.up"
        case .sort: "chevron.up.chevron.down"
        case .inspectorToggle: "sidebar.right"
        case .more: "ellipsis"
        case .copy: "doc.on.doc"
        case .close: "xmark"
        case .signOut: "rectangle.portrait.and.arrow.right"
        // Métricas
        case .balance: "wallet.pass.fill"
        case .expenseFlow: "arrow.down.right.circle.fill"
        case .incomeFlow: "arrow.up.right.circle.fill"
        case .netResult: "chart.line.uptrend.xyaxis"
        // Charts do dashboard
        case .chartCategoryRanking: "chart.bar.xaxis"
        case .chartIncomeExpense: "arrow.up.arrow.down"
        case .chartWeekday: "calendar"
        // Status
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.circle.fill"
        case .info: "info.circle"
        case .unknown: "questionmark.circle"
        case .completedSeal: "checkmark.seal.fill"
        case .invalidDate: "calendar.badge.exclamationmark"
        case .invalidAmount: "dollarsign.circle.trianglebadge.exclamationmark"
        // Sidebar
        case .sidebarDashboard: "chart.pie"
        case .sidebarTransactions: "list.bullet"
        case .sidebarCreditCards: "creditcard"
        case .sidebarAccounts: "building.columns"
        case .sidebarImport: "tray.and.arrow.down"
        case .sidebarCategories: "tag"
        case .sidebarInstitutions: "building.columns"
        case .sidebarDesignSystem: "paintpalette"
        case .sidebarProfile: "person.crop.circle"
        }
    }
}

private struct IconPreview: View {
    private let icons: [Icon] = [
        .add,
        .edit,
        .delete,
        .importFile,
        .success,
        .warning,
        .sidebarDashboard,
        .sidebarTransactions,
        .sidebarCreditCards,
        .sidebarProfile,
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: Theme.Spacing.sm),
    ]

    var body: some View {
        AppUIPreviewSurface(title: "Icon") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(icons, id: \.systemImage) { icon in
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: icon.systemImage)
                            .font(.system(size: Theme.IconSize.large, weight: .semibold))
                            .foregroundStyle(Theme.Palette.tealDeep)
                        Text(icon.systemImage)
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(Theme.Palette.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .granaSurface(.solid, cornerRadius: Theme.Radius.control)
                }
            }
        }
    }
}

#Preview("AppUI.Icon") {
    IconPreview()
}
