import AppUI
import ComposableArchitecture
import SwiftUI

struct ImportTriageView: View {
    @Bindable var store: StoreOf<ImportTriageFeature>
    let onClose: @MainActor @Sendable () -> Void

    var body: some View {
        if let ofxStore = store.scope(state: \.ofx, action: \.ofx) {
            OFXTriageView(
                store: ofxStore,
                sidebarActions: { sidebarActions(canAdvance: canAdvanceOFX) }
            )
        } else if let csvStore = store.scope(state: \.csv, action: \.csv) {
            CSVTriageView(
                store: csvStore,
                sidebarActions: { sidebarActions(canAdvance: canAdvanceCSV) }
            )
        }
    }

    private var canAdvanceOFX: Bool {
        guard let ofx = store.state.ofx else { return false }
        return ofx.totalSelected > 0 && ofx.allAccountsSelected
    }

    private var canAdvanceCSV: Bool {
        guard let csv = store.state.csv else { return false }
        return csv.resolution.selectedCount > 0 && csv.resolution.accountId != nil
    }

    private func sidebarActions(canAdvance: Bool) -> some View {
        Group {
            Button("Fechar") { onClose() }
                .buttonStyle(GranaSecondaryButtonStyle())
                .frame(maxWidth: .infinity)

            Button("Avançar") { store.send(.advanceButtonTapped) }
                .buttonStyle(GranaPrimaryButtonStyle())
                .disabled(!canAdvance)
                .frame(maxWidth: .infinity)
        }
    }
}
