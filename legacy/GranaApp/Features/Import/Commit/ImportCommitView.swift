import AppUI
import ComposableArchitecture
import SwiftUI

struct ImportCommitView: View {
    @Bindable var store: StoreOf<ImportCommitFeature>

    var body: some View {
        ImportWizardStatusView(
            icon: icon,
            title: "Consolidando lotes",
            message: message,
            showsProgress: showsProgress
        )
        .task {
            await store.send(.task).finish()
        }
    }

    private var icon: AppUI.Icon {
        switch store.status {
        case .failed:
            .warning
        default:
            AppUI.Icon.completedSeal
        }
    }

    private var message: String {
        switch store.status {
        case .idle, .committing:
            "Aplicando a revisão e finalizando a importação."
        case let .completed(result):
            "\(result.importedRowCount) transações importadas."
        case let .failed(message):
            message
        }
    }

    private var showsProgress: Bool {
        switch store.status {
        case .idle, .committing:
            true
        case .completed, .failed:
            false
        }
    }
}
