/// Seções principais do app, exibidas no rail lateral autenticado.
///
/// A ordem visual do rail é determinada por `AppNavigationRail`, não pela ordem
/// do `enum`.
enum AppSection: String, Hashable, Identifiable {
    case dashboard
    case transactions
    case creditCards
    case accounts
    case `import`
    case categories
    case institutions
    case designSystem
    case profile

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .transactions: "Transações"
        case .creditCards: "Cartões de crédito"
        case .accounts: "Contas"
        case .import: "Importar dados"
        case .categories: "Categorias"
        case .institutions: "Instituições"
        case .designSystem: "Design System"
        case .profile: "Perfil"
        }
    }

    /// Ícone da seção. Delega pro `AppIcon` (catálogo central de chrome de UI)
    /// pra manter strings de SF Symbol num único lugar e evitar typos.
    var icon: AppIcon {
        switch self {
        case .dashboard: .sidebarDashboard
        case .transactions: .sidebarTransactions
        case .creditCards: .sidebarCreditCards
        case .accounts: .sidebarAccounts
        case .import: .sidebarImport
        case .categories: .sidebarCategories
        case .institutions: .sidebarInstitutions
        case .designSystem: .sidebarDesignSystem
        case .profile: .sidebarProfile
        }
    }
}
