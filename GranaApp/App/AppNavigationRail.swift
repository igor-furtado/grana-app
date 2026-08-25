import SwiftUI

struct AppNavigationRail: View {
    let selection: AppSection
    let onSelect: (AppSection) -> Void

    private static let primaryItems: [AppSection] = [
        .dashboard,
        .transactions,
        .creditCards,
        .accounts,
        .import,
    ]

    private static let bottomItems: [AppSection] = [
        .designSystem,
        .categories,
        .institutions,
        .profile,
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Self.primaryItems) { section in
                railButton(for: section)
            }

            Spacer(minLength: 14)

            ForEach(Self.bottomItems) { section in
                railButton(for: section)
            }
        }
        .padding(10)
        .frame(width: 70)
        .frame(maxHeight: .infinity)
        .granaSurface(.glass, cornerRadius: GranaTheme.Radius.rail)
    }

    private func railButton(for section: AppSection) -> some View {
        let isSelected = selection == section
        return Button {
            onSelect(section)
        } label: {
            Image(systemName: section.icon.systemImage)
                .font(.system(size: GranaTheme.IconSize.medium, weight: .semibold))
                .foregroundStyle(isSelected ? GranaTheme.Palette.creamText : GranaTheme.Palette.muted)
                .frame(width: 48, height: 48)
                .background {
                    if isSelected {
                        GranaTheme.brandGradient()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: GranaTheme.Shadow.accentColor, radius: 17, y: 8)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(section.title)
        .accessibilityLabel(section.title)
    }
}
