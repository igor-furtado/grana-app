import AppUI
import SwiftUI

struct ImportWizardStatusView<Actions: View>: View {
    let icon: AppUI.Icon
    let title: String
    let message: String
    let showsProgress: Bool
    let actions: Actions

    init(
        icon: AppUI.Icon,
        title: String,
        message: String,
        showsProgress: Bool,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.showsProgress = showsProgress
        self.actions = actions()
    }

    var body: some View {
        AppUI.Wizard.Shell {
            IllustratedStatusView(
                title,
                icon: icon,
                description: message
            ) {
                if showsProgress {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 320)
                        .tint(AppUI.Theme.Palette.teal)
                }

                actions
            }
        }
    }
}
