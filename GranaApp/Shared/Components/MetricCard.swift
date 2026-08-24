import SwiftUI

/// Card de métrica única, usado pelos 4 cards do dashboard.
struct MetricCard: View {
    let title: String
    let value: Decimal
    let icon: AppIcon?
    let accent: Color

    /// Mostra "—" em vez do valor. Usado em "Patrimônio investido" enquanto
    /// a Fase 6 não chegou — sinaliza visualmente que a métrica existe mas
    /// ainda não tem dado, em vez de mostrar "R$ 0,00" (que confundiria com
    /// "tem 0 reais investidos").
    var placeholder: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon.systemImage)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(accent)
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(GranaTheme.Palette.muted)
            }

            Text(placeholder ? "—" : value.formatted(.currency(code: "BRL")))
                .font(GranaTheme.Typography.number(size: 30, weight: .bold))
                .foregroundStyle(placeholder ? GranaTheme.Palette.muted : GranaTheme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
    }
}
