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
                    onBrowse: { historyStore.send(.importButtonTapped(nil)) }
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
        FeatureScreenHeader(
            title: "Importar transações",
            subtitle: historyStore.summarySubtitle
        ) {
            HStack(spacing: GranaTheme.Spacing.sm) {
                Button {
                    historyStore.send(.importButtonTapped(nil))
                } label: {
                    Label("Selecionar arquivo", systemImage: AppIcon.importFile.systemImage)
                }
                .buttonStyle(GranaSecondaryButtonStyle())

                Button {
                    historyStore.send(.importButtonTapped(nil))
                } label: {
                    Label("Nova importação", systemImage: AppIcon.add.systemImage)
                }
                .buttonStyle(GranaPrimaryButtonStyle())
                .help("Importar extrato bancário (OFX ou CSV)")
            }
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
    var importedAtText: String { batch.importedAt.formatted(date: .abbreviated, time: .shortened) }
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
                        Text(row.institutionName)
                            .font(GranaTheme.Typography.subheadlineEmphasis)
                            .foregroundStyle(GranaTheme.Palette.ink)
                            .lineLimit(1)
                    }
                    .help(row.institutionName)
                }
                .width(min: 180, ideal: 220, max: 260)

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
                .width(min: 220, ideal: 320)

                TableColumn("Conta", value: \.accountName) { row in
                    Text(row.accountName)
                        .font(GranaTheme.Typography.subheadline)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .lineLimit(1)
                        .help(row.accountName)
                }
                .width(min: 180, ideal: 220)

                TableColumn("Linhas", value: \.rowCount) { row in
                    Text("\(row.batch.rowCount)")
                        .font(GranaTheme.Typography.subheadlineEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 72, ideal: 86, max: 96)

                TableColumn("Importado", value: \.importedAt) { row in
                    Text(row.importedAtText)
                        .font(GranaTheme.Typography.footnote)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 170, ideal: 190, max: 220)

                TableColumn("Ações") { row in
                    Button(role: .destructive) {
                        onUndo(row)
                    } label: {
                        Label("Desfazer", systemImage: AppIcon.undo.systemImage)
                    }
                    .buttonStyle(.borderless)
                    .help("Desfazer lote")
                }
                .width(min: 110, ideal: 128, max: 144)
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
        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
            importFilterMenu(
                title: "Instituição",
                value: institutionFilter,
                options: institutionOptions,
                selection: $institutionFilter
            )
            filterSearchField(title: "Arquivo", prompt: "Buscar arquivo", text: $filenameFilter)
            filterSearchField(title: "Conta", prompt: "Buscar conta", text: $accountFilter)
        }
    }

    private func importFilterMenu(
        title: String,
        value: String,
        options: [String],
        selection: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
            Text(title)
                .font(GranaTheme.Typography.caption2Emphasis)
                .foregroundStyle(GranaTheme.Palette.muted)
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection.wrappedValue = option
                    }
                }
            } label: {
                filterChip(value: value, icon: "building.columns")
            }
            .buttonStyle(.plain)
        }
        .frame(width: 220, alignment: .leading)
    }

    private func filterSearchField(
        title: String,
        prompt: String,
        text: Binding<String>
    ) -> some View {
        AppUI.TextField(
            label: title,
            text: text,
            placeholder: prompt,
            leadingSystemImage: "magnifyingglass",
            showsClearButton: true,
            font: GranaTheme.Typography.footnoteEmphasis,
            textAlignment: .leading
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func filterChip(value: String, icon: String) -> some View {
        HStack(spacing: GranaTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(GranaTheme.Palette.tealDeep)
            Text(value)
                .font(GranaTheme.Typography.footnoteEmphasis)
                .foregroundStyle(GranaTheme.Palette.ink)
                .lineLimit(1)
            Spacer(minLength: GranaTheme.Spacing.none)
            Image(systemName: "chevron.down")
                .font(.system(size: GranaTheme.IconSize.micro, weight: .semibold))
                .foregroundStyle(GranaTheme.Palette.muted)
        }
        .padding(.horizontal, GranaTheme.Spacing.sm)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GranaTheme.Palette.paper.opacity(0.92))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GranaTheme.Palette.line, lineWidth: 1)
        }
    }
}

private struct EmptyStateDropZone: View {
    let isHighlighted: Bool
    let onBrowse: () -> Void

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
            HStack(spacing: GranaTheme.Spacing.sm) {
                ImportEmptyStateInfoPill(icon: AppIcon.sidebarAccounts.systemImage, title: "OFX bancário")
                ImportEmptyStateInfoPill(icon: AppIcon.sidebarCreditCards.systemImage, title: "CSV de fatura")
                ImportEmptyStateInfoPill(icon: AppIcon.completedSeal.systemImage, title: "Revisão antes do commit")
            }
            Button {
                onBrowse()
            } label: {
                Label("Selecionar arquivo", systemImage: AppIcon.importFile.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(GranaTheme.Spacing.xxxl)
        .background {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                .fill(GranaTheme.Palette.paper.opacity(0.62))
        }
        .overlay {
            RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                .strokeBorder(
                    GranaTheme.Palette.teal.opacity(isHighlighted ? 0.46 : 0.24),
                    style: StrokeStyle(lineWidth: isHighlighted ? 2 : 1.4, dash: [10, 8])
                )
        }
        .shadow(color: GranaTheme.Shadow.cardColor, radius: 18, y: 8)
        .scaleEffect(isHighlighted ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.18), value: isHighlighted)
    }
}

private struct ImportEmptyStateInfoPill: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: GranaTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(GranaTheme.Palette.tealDeep)
            Text(title)
                .font(GranaTheme.Typography.caption1Emphasis)
                .foregroundStyle(GranaTheme.Palette.ink)
        }
        .padding(.horizontal, GranaTheme.Spacing.sm)
        .padding(.vertical, GranaTheme.Spacing.xs)
        .background(GranaTheme.Palette.paperSolid.opacity(0.84), in: Capsule())
    }
}
