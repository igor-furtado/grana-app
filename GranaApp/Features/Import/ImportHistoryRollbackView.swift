import SwiftUI
import AppUI

struct ImportHistoryRollbackView: View {
    let batch: ImportBatch
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            GranaBackground()

            AppUI.Form.Shell {
                AppUI.Form.Header(
                    title: "Desfazer importação?",
                    subtitle: batch.sourceFilename
                )

                messageBlock

                AppUI.Form.Actions {
                    Button("Cancelar", action: onCancel)
                        .buttonStyle(GranaSecondaryButtonStyle())

                    Button("Apagar lote (\(batch.rowCount) transações)", action: onConfirm)
                        .buttonStyle(GranaDestructiveButtonStyle())
                }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(width: AppUI.Modal.SheetSize.compactWidth)
        .presentationSizing(.fitted)
    }

    private var messageBlock: some View {
        Text("As \(batch.rowCount) transações deste lote serão removidas permanentemente.")
            .font(AppUI.Theme.Typography.callout)
            .foregroundStyle(AppUI.Theme.Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppUI.Theme.Spacing.lg)
    }
}
