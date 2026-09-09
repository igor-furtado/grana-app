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
                sidebarActions: {
                    sidebarActions(canAdvance: canAdvanceOFX, selectedCount: ofxStore.state.totalSelected)
                }
            )
        } else if let csvStore = store.scope(state: \.csv, action: \.csv) {
            CSVTriageView(
                store: csvStore,
                resolution: Binding(
                    get: { csvStore.state.resolution },
                    set: { csvStore.send(.resolutionUpdated($0)) }
                ),
                institutionKind: csvStore.state.bankKind(for: csvStore.state.resolution.accountId),
                onNegativeSelectionChanged: { rowId, isSelected in
                    csvStore.send(.negativeSelectionChanged(rowId: rowId, isSelected: isSelected))
                },
                sidebarActions: { sidebarActions(
                    canAdvance: canAdvanceCSV,
                    selectedCount: csvStore.state.resolution.selectedCount
                ) }
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

    private func sidebarActions(canAdvance: Bool, selectedCount: Int) -> some View {
        Group {
            Button("Fechar") { onClose() }
                .buttonStyle(GranaSecondaryButtonStyle())
                .frame(maxWidth: .infinity)

            Button(advanceButtonTitle(selectedCount: selectedCount)) { store.send(.advanceButtonTapped) }
                .buttonStyle(GranaPrimaryButtonStyle())
                .disabled(!canAdvance)
                .frame(maxWidth: .infinity)
        }
    }

    private func advanceButtonTitle(selectedCount: Int) -> String {
        if selectedCount == 1 {
            return "Avançar com 1 transação"
        }
        return "Avançar com \(selectedCount) transações"
    }
}
