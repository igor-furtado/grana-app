import SwiftUI

/// Tela de manutenção de baixo nível. Após a refatoração online-only o app não
/// mantém mais um banco financeiro local apagável pela UI.
struct AdvancedSettingsView: View {
    var body: some View {
        Form {
            Section("Estado local") {
                Label("Não há banco financeiro local para apagar.", systemImage: "externaldrive.badge.checkmark")
                    .foregroundStyle(.secondary)
                Text(
                    "O app mantém apenas preferências de interface e sessão autenticada. Contas, transações, faturas e históricos de importação vivem somente no backend."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Avançado")
    }
}
