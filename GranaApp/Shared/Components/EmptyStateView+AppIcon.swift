import SwiftUI

extension EmptyStateView where Icon == EmptyStateSymbolIcon {
    init(
        _ title: String,
        icon: AppIcon,
        description: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(title, description: description) {
            EmptyStateSymbolIcon(systemName: icon.systemImage)
        } actions: {
            actions()
        }
    }
}

extension EmptyStateView where Icon == EmptyStateSymbolIcon, Actions == EmptyView {
    init(
        _ title: String,
        icon: AppIcon,
        description: String? = nil
    ) {
        self.init(title, description: description) {
            EmptyStateSymbolIcon(systemName: icon.systemImage)
        }
    }
}
