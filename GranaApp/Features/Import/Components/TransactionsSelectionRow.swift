import SwiftUI

/// Linha de controle de seleção que vai **dentro do scroll**, logo antes das
/// rows de transação. Fica abaixo do header `Section` (que tem só o título
/// "Transações") pra o checkbox master alinhar verticalmente com a coluna
/// de checkboxes das rows.
///
/// Compartilhada entre [OFXReviewStepView] e [CSVReviewStepView] — ambos os
/// fluxos do wizard precisam do mesmo controle "marcar/desmarcar todas".
struct TransactionsSelectionRow: View {
    let summary: String
    let allSelected: Bool
    let onToggleAll: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: GranaTheme.Spacing.sm) {
            AppUI.Toggle(label: allSelected ? "Desmarcar todas" : "Marcar todas", isOn: Binding(
                get: { allSelected },
                set: { onToggleAll($0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            Text(summary)
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, GranaTheme.Spacing.md)
        .padding(.vertical, GranaTheme.Spacing.xs)
        .background(Color.primary.opacity(0.03))
    }
}
