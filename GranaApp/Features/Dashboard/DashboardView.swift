import SwiftUI
import AppUI

struct DashboardView: View {
    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Layout.ScreenHeader(
                title: "Dashboard",
                subtitle: "Esta seção permanece disponível, mas está sem visualizações nesta fase."
            )

            EmptyStateView(
                "Dashboard sem funcionalidade",
                icon: .sidebarDashboard,
                description: """
                    Os indicadores e gráficos do dashboard foram removidos.
                    Use as demais seções para consultar e organizar seus dados financeiros.
                    """
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
    }
}
