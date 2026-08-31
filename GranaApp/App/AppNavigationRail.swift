import SwiftUI
import AppUI

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
        VStack(spacing: AppUI.Theme.Spacing.xs) {
            ForEach(Self.primaryItems) { section in
                railButton(for: section)
            }

            Spacer(minLength: AppUI.Theme.Spacing.md)

            ForEach(Self.bottomItems) { section in
                railButton(for: section)
            }
        }
        .padding(AppUI.Theme.Spacing.sm)
        .frame(width: 70)
        .frame(maxHeight: .infinity)
        .granaSurface(.glass, cornerRadius: AppUI.Theme.Radius.rail)
    }

    private func railButton(for section: AppSection) -> some View {
        let isSelected = selection == section
        return Button {
            onSelect(section)
        } label: {
            Image(systemName: section.icon.systemImage)
                .font(.system(size: AppUI.Theme.IconSize.medium, weight: .semibold))
                .foregroundStyle(isSelected ? AppUI.Theme.Palette.creamText : AppUI.Theme.Palette.muted)
                .frame(width: 48, height: 48)
                .background {
                    if isSelected {
                        AppUI.Theme.brandGradient()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: AppUI.Theme.Shadow.accentColor, radius: 17, y: 8)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(section.title)
        .accessibilityLabel(section.title)
    }
}
