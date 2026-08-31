import ComposableArchitecture
import SwiftUI

struct ImportHistoryView: View {
    @Bindable var store: StoreOf<ImportFeature>
    @State private var sortOrder = [
        KeyPathComparator(\ImportHistoryBatchPresentation.importedAt, order: .reverse),
    ]
    @State private var institutionFilter = "Todas"
    @State private var filenameFilter = ""
    @State private var accountFilter = ""

    var body: some View {
        ImportHistoryContentView(
            store: store,
            sortOrder: $sortOrder,
            institutionFilter: $institutionFilter,
            filenameFilter: $filenameFilter,
            accountFilter: $accountFilter
        )
    }
}

private struct ImportHistoryContentView: View {
    @Bindable var store: StoreOf<ImportFeature>
    @Binding var sortOrder: [KeyPathComparator<ImportHistoryBatchPresentation>]
    @Binding var institutionFilter: String
    @Binding var filenameFilter: String
    @Binding var accountFilter: String

    private var historyStore: StoreOf<ImportHistoryFeature> {
        store.scope(state: \.history, action: \.history)
    }

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            header

            if historyStore.snapshot.batches.isEmpty {
                EmptyStateDropZone(
                    isHighlighted: false,
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                dashboard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
        .confirmationDialog(
            "Desfazer importação?",
            isPresented: Binding(
                get: { historyStore.pendingDelete != nil },
                set: { isPresented in
                    if !isPresented {
                        historyStore.send(.confirmationDialog(.dismiss))
                    }
                }
            )
        ) {
            if let batch = historyStore.pendingDelete {
                Button("Apagar lote (\(batch.rowCount) transações)", role: .destructive) {
                    historyStore.send(.confirmationDialog(.presented(.deleteConfirmed)))
                }
                Button("Cancelar", role: .cancel) {
                    historyStore.send(.confirmationDialog(.dismiss))
                }
            }
        } message: {
            if let batch = historyStore.pendingDelete {
                Text("As \(batch.rowCount) transações de **\(batch.sourceFilename)** serão removidas permanentemente.")
            }
        }
        .task {
            await historyStore.send(.task).finish()
        }
    }

    private var header: some View {
        AppUI.Layout.ScreenHeader(
            title: "Importar transações",
            subtitle: historyStore.summarySubtitle
        ) {
            Button {
                historyStore.send(.importButtonTapped(nil))
            } label: {
                Label("Nova importação", systemImage: AppIcon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .help("Importar extrato bancário (OFX ou CSV)")
        }
    }

    private var dashboard: some View {
        let rows = filteredRows(from: presentationRows(for: historyStore.snapshot.batches))
        return ImportHistoryMainPanel(
            rows: rows,
            sortOrder: $sortOrder,
            institutionFilter: $institutionFilter,
            filenameFilter: $filenameFilter,
            accountFilter: $accountFilter,
            onUndo: { row in historyStore.send(.undoButtonTapped(row.batch)) }
        )
    }

    private func presentationRows(for batches: [ImportBatch]) -> [ImportHistoryBatchPresentation] {
        batches
            .sorted { $0.importedAt > $1.importedAt }
            .map { batch in
                ImportHistoryBatchPresentation(
                    batch: batch,
                    accountDisplayName: accountDisplayName(for: batch),
                    institution: institution(for: batch)
                )
            }
    }

    private func filteredRows(from rows: [ImportHistoryBatchPresentation]) -> [ImportHistoryBatchPresentation] {
        rows
            .filter { row in
                institutionFilter == "Todas" || row.institutionName == institutionFilter
            }
            .filter { row in
                filenameFilter.isEmpty
                    || row.batch.sourceFilename.localizedCaseInsensitiveContains(filenameFilter)
            }
            .filter { row in
                accountFilter.isEmpty
                    || row.accountName.localizedCaseInsensitiveContains(accountFilter)
            }
            .sorted(using: sortOrder)
    }

    private func institution(for batch: ImportBatch) -> Institution? {
        guard let account = historyStore.state.account(for: batch.accountId),
              let institutionId = account.institutionId
        else { return nil }
        return historyStore.snapshot.institutions.first { $0.id == institutionId }
    }

    private func accountDisplayName(for batch: ImportBatch) -> String? {
        guard let account = historyStore.state.account(for: batch.accountId) else { return nil }
        return Account.displayName(
            for: account,
            institutions: historyStore.snapshot.institutions,
            bankAccounts: historyStore.snapshot.bankDetails,
            creditCards: historyStore.snapshot.creditCards
        )
    }
}

private struct ImportHistoryBatchPresentation: Identifiable {
    let batch: ImportBatch
    let accountDisplayName: String?
    let institution: Institution?

    var id: UUID { batch.id }
    var institutionKind: InstitutionKind { institution?.kind ?? .other }
    var institutionName: String { institution?.name ?? "Conta desconhecida" }
    var accountName: String { accountDisplayName ?? institutionName }

    var formatName: String {
        let ext = URL(fileURLWithPath: batch.sourceFilename).pathExtension
        return ext.isEmpty ? "ARQ" : ext.uppercased()
    }

    var sourceFilename: String { batch.sourceFilename }
    var rowCount: Int { batch.rowCount }
    var importedAtText: String { GranaDateFormat.dateTime(batch.importedAt) }
    var importedAt: Date { batch.importedAt }
}

private struct ImportHistoryMainPanel: View {
    let rows: [ImportHistoryBatchPresentation]
    @Binding var sortOrder: [KeyPathComparator<ImportHistoryBatchPresentation>]
    @Binding var institutionFilter: String
    @Binding var filenameFilter: String
    @Binding var accountFilter: String
    let onUndo: (ImportHistoryBatchPresentation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.none) {
            AppUI.Table(rows, sortOrder: $sortOrder) {
                TableColumn("Instituição", value: \.institutionName) { row in
                    HStack(spacing: GranaTheme.Spacing.sm) {
                        InstitutionIcon(kind: row.institutionKind, size: 24)
                        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                            Text(row.institutionName)
                                .font(GranaTheme.Typography.subheadlineEmphasis)
                                .foregroundStyle(GranaTheme.Palette.ink)
                                .lineLimit(1)
                            Text(row.accountName)
                                .font(GranaTheme.Typography.caption1)
                                .foregroundStyle(GranaTheme.Palette.muted)
                                .lineLimit(1)
                        }
                    }
                }
                .width(min: 210, ideal: 240, max: 240)

                TableColumn("Importado", value: \.importedAt) { row in
                    Text(row.importedAtText)
                        .font(GranaTheme.Typography.footnote)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 125, ideal: 140, max: 140)

                TableColumn("Arquivo", value: \.sourceFilename) { row in
                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                        Text(row.batch.sourceFilename)
                            .font(GranaTheme.Typography.subheadlineEmphasis)
                            .foregroundStyle(GranaTheme.Palette.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(row.formatName)
                            .font(GranaTheme.Typography.caption2Emphasis)
                            .foregroundStyle(GranaTheme.Palette.tealDeep)
                    }
                    .help(row.batch.sourceFilename)
                }

                TableColumn("Linhas", value: \.rowCount) { row in
                    Text("\(row.batch.rowCount)")
                        .font(GranaTheme.Typography.subheadlineEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 70, ideal: 80, max: 80)

                TableColumn("Ações") { row in
                    Button(role: .destructive) {
                        onUndo(row)
                    } label: {
                        Label("Desfazer", systemImage: AppIcon.undo.systemImage)
                    }
                    .buttonStyle(.borderless)
                    .help("Desfazer lote")
                }
                .width(min: 70, ideal: 80, max: 90)
            } filterBar: {
                ImportHistoryFilterBar(
                    institutionOptions: institutionOptions,
                    institutionFilter: $institutionFilter,
                    filenameFilter: $filenameFilter,
                    accountFilter: $accountFilter
                )
            }
        }
    }

    private var institutionOptions: [String] {
        ["Todas"] + Array(Set(rows.map(\.institutionName))).sorted()
    }
}

private struct ImportHistoryFilterBar: View {
    let institutionOptions: [String]
    @Binding var institutionFilter: String
    @Binding var filenameFilter: String
    @Binding var accountFilter: String

    var body: some View {
        AppUI.TableFilterBar {
            AppUI.Selector(
                label: "Instituição",
                options: institutionOptions.map { .init(id: $0, title: $0) },
                selection: $institutionFilter,
                icon: "building.columns"
            )
            .frame(width: 220, alignment: .leading)

            AppUI.TextField(
                label: "Arquivo",
                text: $filenameFilter,
                placeholder: "Buscar arquivo",
                leadingSystemImage: "magnifyingglass",
                showsClearButton: true,
                font: GranaTheme.Typography.footnoteEmphasis,
                textAlignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            AppUI.TextField(
                label: "Conta",
                text: $accountFilter,
                placeholder: "Buscar conta",
                leadingSystemImage: "magnifyingglass",
                showsClearButton: true,
                font: GranaTheme.Typography.footnoteEmphasis,
                textAlignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct EmptyStateDropZone: View {
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(GranaTheme.Palette.teal.opacity(isHighlighted ? 0.18 : 0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: AppIcon.importFile.systemImage)
                    .font(.system(size: GranaTheme.IconSize.hero, weight: .regular))
                    .foregroundStyle(GranaTheme.Palette.tealDeep)
                    .symbolEffect(.bounce, value: isHighlighted)
            }
            VStack(spacing: GranaTheme.Spacing.sm) {
                Text(isHighlighted ? "Solte o extrato para revisar" : "Importe o primeiro extrato")
                    .font(GranaTheme.Typography.title2)
                    .foregroundStyle(GranaTheme.Palette.ink)
                    .multilineTextAlignment(.center)
                Text("Arraste um arquivo para a tela ou selecione manualmente. O fluxo revisa OFX e CSV antes do commit definitivo.")
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(GranaTheme.Spacing.xxxl)
      
        .overlay {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                .strokeBorder(
                    GranaTheme.Palette.teal.opacity(0.40),
                    style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                )
        }
    }
}
