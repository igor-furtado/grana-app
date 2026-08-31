import SwiftUI
import AppUI

struct BottomActionBar<Trailing: View>: View {
    let caption: String?
    @ViewBuilder var trailing: () -> Trailing

    init(
        caption: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.caption = caption
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: AppUI.Theme.Spacing.sm) {
            if let caption {
                Text(caption)
                    .font(AppUI.Theme.Typography.caption1)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
                .controlSize(.large)
        }
        .padding(.horizontal, AppUI.Theme.Spacing.lg)
    }
}
