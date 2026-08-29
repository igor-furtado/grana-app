import ComposableArchitecture
import Foundation
import SwiftUI

struct StatementDateEditorView: View {
    @Bindable var store: StoreOf<StatementDateEditorFeature>

    var body: some View {
        ZStack {
            GranaBackground()

            AppUI.Form.Shell {
                header

                Form {
                    dateSection
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

                actions
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 560, idealWidth: 560, maxWidth: 560, minHeight: 360)
        .environment(\.timeZone, TimeZone(secondsFromGMT: 0) ?? .current)
        .onExitCommand {
            store.send(.cancelButtonTapped)
        }
    }

    private var header: some View {
        AppUI.Form.Header(title: store.title, subtitle: "Datas próprias desta fatura.")
    }

    private var dateSection: some View {
        Section {
            AppUI.DatePicker(
                label: "Data de fechamento",
                selection: $store.closingDate,
                displayedComponents: .date,
                isEnabled: !store.isSaving
            )
            AppUI.DatePicker(
                label: "Data de vencimento",
                selection: $store.dueDate,
                displayedComponents: .date,
                isEnabled: !store.isSaving
            )
        } header: {
            AppUI.Form.SectionHeader(title: "Datas da fatura")
        } footer: {
            AppUI.Form.SectionFooter(
                text: "Alterar o fechamento realoca compras e créditos entre faturas. Pagamentos permanecem na fatura onde foram registrados."
            )
        }
    }

    private var actions: some View {
        AppUI.Form.Actions {
            Button("Cancelar") {
                store.send(.cancelButtonTapped)
            }
            .buttonStyle(GranaSecondaryButtonStyle())
            .disabled(store.isSaving)

            Button {
                store.send(.saveButtonTapped)
            } label: {
                if store.isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 88)
                } else {
                    Text("Salvar datas")
                        .frame(minWidth: 88)
                }
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(store.isSaving)
        }
    }
}
