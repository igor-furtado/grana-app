import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ImportHistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: ImportStore?
    @State private var pendingDeleteBatch: ImportBatch?
    @State private var importContext: ImportContext?
    @State private var isDropTargeted = false
    @State private var sortOrder = [
        KeyPathComparator(\ImportHistoryBatchPresentation.importedAt, order: .reverse),
    ]
    @State private var institutionFilter: String = "Todas"
    @State private var filenameFilter = ""
    @State private var accountFilter = ""

    private struct ImportContext: Identifiable {
        let id = UUID()
        let file: URL?
    }

    var body: some View {
        Group {
            if let store {
                content(store: store)
                    .task { await store.start() }
                    .task {
                        for await _ in NotificationCenter.default.notifications(
                            named: ImportStore.didMutateImportsNotification
                        ) {
                            await store.refresh()
                        }
                    }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { store = ImportStore(container: environment.container) }
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
        .dropDestination(for: URL.self, action: handleDrop, isTargeted: setDropTargeted)
        .overlay {
            if isDropTargeted, !(store?.batches.isEmpty ?? true) {
                DropOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isDropTargeted)
        .sheet(
            item: $importContext,
            onDismiss: {
                guard let store else { return }
                Task { await store.refresh() }
            },
            content: { context in
                ImportView(initialFile: context.file)
                    .environment(environment)
            }
        )
    }

    private func content(store: ImportStore) -> some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            header(store: store)

            if store.batches.isEmpty {
                EmptyStateDropZone(
                    isHighlighted: isDropTargeted,
                    onBrowse: { presentImportSheet(file: nil) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                dashboard(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .confirmationDialog(
            "Desfazer importação?",
            isPresented: Binding(
                get: { pendingDeleteBatch != nil },
                set: { if !$0 { pendingDeleteBatch = nil } }
            ),
            presenting: pendingDeleteBatch
        ) { batch in
            Button("Apagar lote (\(batch.rowCount) transações)", role: .destructive) {
                Task {
                    await store.undo(batchId: batch.id)
                    pendingDeleteBatch = nil
                }
            }
            Button("Cancelar", role: .cancel) { pendingDeleteBatch = nil }
        } message: { batch in
            Text(
                "As \(batch.rowCount) transações de **\(batch.sourceFilename)** serão removidas permanentemente."
            )
        }
    }

    private func header(store: ImportStore) -> some View {
        FeatureScreenHeader(
            title: "Importar transações",
            subtitle: store.summarySubtitle
        ) {
            HStack(spacing: GranaTheme.Spacing.sm) {
                ImportSummaryBadge(
                    title: "Lotes",
                    value: "\(store.batches.count)",
                    detail: "histórico ativo"
                )
                ImportSummaryBadge(
                    title: "Linhas",
                    value: "\(store.totalImportedRows)",
                    detail: "já consolidadas"
                )
                ImportSummaryBadge(
                    title: "Última",
                    value: store.latestImportShortText,
                    detail: "importação concluída"
                )
            }
        } actions: {
            HStack(spacing: GranaTheme.Spacing.sm) {
                Button {
                    presentImportSheet(file: nil)
                } label: {
                    Label("Selecionar arquivo", systemImage: AppIcon.importFile.systemImage)
                }
                .buttonStyle(GranaSecondaryButtonStyle())

                Button {
                    presentImportSheet(file: nil)
                } label: {
                    Label("Nova importação", systemImage: AppIcon.add.systemImage)
                }
                .buttonStyle(GranaPrimaryButtonStyle())
                .help("Importar extrato bancário (OFX ou CSV)")
            }
        }
    }

    private func dashboard(store: ImportStore) -> some View {
        let rows = filteredRows(from: presentationRows(for: store.batches, store: store))
        return ImportHistoryMainPanel(
            rows: rows,
            sortOrder: $sortOrder,
            institutionFilter: $institutionFilter,
            filenameFilter: $filenameFilter,
            accountFilter: $accountFilter,
            onUndo: { row in pendingDeleteBatch = row.batch }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func presentationRows(
        for batches: [ImportBatch],
        store: ImportStore
    ) -> [ImportHistoryBatchPresentation] {
        batches
            .sorted { $0.importedAt > $1.importedAt }
            .map { batch in
                ImportHistoryBatchPresentation(
                    batch: batch,
                    accountDisplayName: accountDisplayName(for: batch, store: store),
                    institution: institution(for: batch, store: store)
                )
            }
    }

    private func filteredRows(
        from rows: [ImportHistoryBatchPresentation]
    ) -> [ImportHistoryBatchPresentation] {
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

    private func institution(for batch: ImportBatch, store: ImportStore) -> Institution? {
        guard let account = store.account(for: batch.accountId),
              let id = account.institutionId else { return nil }
        return store.institutions.first { $0.id == id }
    }

    private func accountDisplayName(for batch: ImportBatch, store: ImportStore) -> String? {
        guard let account = store.account(for: batch.accountId) else { return nil }
        return Account.displayName(
            for: account,
            institutions: store.institutions,
            bankAccounts: store.bankDetails,
            creditCards: store.creditCards
        )
    }

    private func presentImportSheet(file: URL?) {
        importContext = ImportContext(file: file)
    }

    private func handleDrop(_ urls: [URL], at _: CGPoint) -> Bool {
        guard let url = urls.first else { return false }
        let ext = url.pathExtension.lowercased()

        guard ImportStore.supportedExtensions.contains(ext) else {
            NoticeCenter.shared.report(
                ImportError.unsupportedFormat(extension: ext.isEmpty ? "(sem extensão)" : ext),
                title: "Arquivo não suportado"
            )
            return false
        }

        if urls.count > 1 {
            NoticeCenter.shared.info(
                title: "Vários arquivos soltos",
                message: "Importe um por vez. Abrindo \"\(url.lastPathComponent)\"."
            )
        }

        presentImportSheet(file: url)
        return true
    }

    private func setDropTargeted(_ targeted: Bool) {
        isDropTargeted = targeted
    }
}

private struct ImportHistoryBatchPresentation: Identifiable {
    let batch: ImportBatch
    let accountDisplayName: String?
    let institution: Institution?

    var id: UUID {
        batch.id
    }

    var institutionKind: InstitutionKind {
        institution?.kind ?? .other
    }

    var institutionName: String {
        institution?.name ?? "Conta desconhecida"
    }

    var accountName: String {
        accountDisplayName ?? institutionName
    }

    var formatName: String {
        let ext = URL(fileURLWithPath: batch.sourceFilename).pathExtension
        guard !ext.isEmpty else { return "ARQ" }
        return ext.uppercased()
    }

    var sourceFilename: String {
        batch.sourceFilename
    }

    var rowCount: Int {
        batch.rowCount
    }

    var importedAtText: String {
        batch.importedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var importedAt: Date {
        batch.importedAt
    }
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
            GranaTable(rows, sortOrder: $sortOrder) {
                TableColumn("Instituição", value: \.institutionName) { (row: ImportHistoryBatchPresentation) in
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

                TableColumn("Arquivo", value: \.sourceFilename) { (row: ImportHistoryBatchPresentation) in
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

                TableColumn("Conta", value: \.accountName) { (row: ImportHistoryBatchPresentation) in
                    Text(row.accountName)
                        .font(GranaTheme.Typography.subheadline)
                        .foregroundStyle(GranaTheme.Palette.muted)
                        .lineLimit(1)
                        .help(row.accountName)
                }
                .width(min: 180, ideal: 220)

                TableColumn("Linhas", value: \.rowCount) { (row: ImportHistoryBatchPresentation) in
                    Text("\(row.batch.rowCount)")
                        .font(GranaTheme.Typography.subheadlineEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 72, ideal: 86, max: 96)

                TableColumn("Importado", value: \.importedAt) { (row: ImportHistoryBatchPresentation) in
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
            .padding(GranaTheme.Spacing.md)
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

            filterSearchField(
                title: "Arquivo",
                prompt: "Buscar arquivo",
                text: $filenameFilter
            )

            filterSearchField(
                title: "Conta",
                prompt: "Buscar conta",
                text: $accountFilter
            )
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
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
            Text(title)
                .font(GranaTheme.Typography.caption2Emphasis)
                .foregroundStyle(GranaTheme.Palette.muted)

            HStack(spacing: GranaTheme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.tealDeep)

                TextField(prompt, text: text)
                    .textFieldStyle(.plain)
                    .font(GranaTheme.Typography.footnoteEmphasis)

                if !text.wrappedValue.isEmpty {
                    Button {
                        text.wrappedValue = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(GranaTheme.Palette.muted)
                    }
                    .buttonStyle(.plain)
                }
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

private struct ImportSummaryBadge: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
            Text(title)
                .font(GranaTheme.Typography.caption2Emphasis)
                .foregroundStyle(GranaTheme.Palette.muted)
            Text(value)
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)
            Text(detail)
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(GranaTheme.Palette.muted)
        }
        .padding(GranaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.control)
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
                Text(
                    "Arraste um arquivo para a tela ou selecione manualmente. O fluxo revisa OFX e CSV antes do commit definitivo."
                )
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

private struct DropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(0.84)

            VStack(spacing: GranaTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(GranaTheme.Palette.teal.opacity(0.18))
                        .frame(width: 96, height: 96)
                    Image(systemName: AppIcon.importFile.systemImage)
                        .font(.system(size: GranaTheme.IconSize.hero, weight: .regular))
                        .foregroundStyle(GranaTheme.Palette.tealDeep)
                }
                Text("Solte para importar")
                    .font(GranaTheme.Typography.title3)
                    .foregroundStyle(GranaTheme.Palette.ink)
                Text("OFX ou CSV")
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
            .padding(GranaTheme.Spacing.xxxl)
            .background {
                RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                    .fill(GranaTheme.Palette.paper.opacity(0.92))
            }
            .overlay {
                RoundedRectangle(cornerRadius: GranaTheme.Radius.hero, style: .continuous)
                    .strokeBorder(
                        GranaTheme.Palette.teal.opacity(0.40),
                        style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                    )
            }
            .shadow(color: GranaTheme.Shadow.cardColor, radius: 24, y: 10)
            .padding(GranaTheme.Spacing.xxxl)
        }
    }
}

private extension ImportStore {
    var totalImportedRows: Int {
        batches.reduce(0) { $0 + $1.rowCount }
    }

    var summarySubtitle: String {
        if batches.isEmpty {
            return "OFX e CSV com revisão antes do commit"
        }
        return "\(batches.count) \(batches.count == 1 ? "importação" : "importações") no histórico"
    }

    var latestImportShortText: String {
        guard let latest = batches.max(by: { $0.importedAt < $1.importedAt }) else {
            return "Sem histórico"
        }
        return latest.importedAt.formatted(date: .numeric, time: .omitted)
    }

    var latestImportLongText: String {
        guard let latest = batches.max(by: { $0.importedAt < $1.importedAt }) else {
            return "Nenhum lote importado ainda"
        }
        return latest.importedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var latestImportedAccountName: String {
        guard let latest = batches.max(by: { $0.importedAt < $1.importedAt }),
              let account = account(for: latest.accountId)
        else {
            return "Sem conta associada"
        }

        return Account.displayName(
            for: account,
            institutions: institutions,
            bankAccounts: bankDetails,
            creditCards: creditCards
        )
    }

    static var supportedExtensionsDisplayText: String {
        supportedExtensions
            .map { $0.uppercased() }
            .sorted()
            .joined(separator: " · ")
    }
}
