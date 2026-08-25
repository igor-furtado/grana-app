import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Tela "Importações" do menu lateral: lista visual de `ImportBatch` agrupada
/// por período (Hoje / Ontem / Esta semana / Este mês / Mais antigos), com
/// logo da instituição em cada card e botão de desfazer. Window toolbar tem
/// o "+" que abre a `ImportView` em sheet modal.
///
/// **Drag & drop:** a tela inteira é um drop target. Arrastar um arquivo OFX
/// ou CSV pra dentro abre o wizard com o arquivo já carregado, pulando o file
/// picker do sistema. Tipos inválidos viram toast via `NoticeCenter` —
/// usuário não fica olhando uma tela "que não fez nada".
struct ImportHistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: ImportStore?
    @State private var pendingDeleteBatch: ImportBatch?
    @State private var importContext: ImportContext?
    @State private var isDropTargeted = false
    @State private var selectedBatchId: UUID?

    /// Wrapper `Identifiable` que carrega o arquivo escolhido (nil = manual)
    /// pra dentro da `.sheet(item:)`. Usamos `.sheet(item:)` em vez de
    /// `.sheet(isPresented:)` porque a versão isPresented tem um race entre
    /// o flag e a URL: dois `@State` mutados em sequência podem ser lidos
    /// pela closure de conteúdo em ordens diferentes, fazendo o wizard
    /// abrir com `initialFile == nil` mesmo após drop bem-sucedido. Com
    /// `.sheet(item:)`, o valor é atômico — quando o sheet abre, o item já
    /// está completo, sem janela pra estado intermediário.
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
        .navigationTitle("Importar dados")
        .navigationSubtitle(importsSubtitle)
        // Drop destination cobre a área inteira da tela — incluindo o empty
        // state e a lista populada. O `isTargeted` dirige o overlay visual.
        .dropDestination(for: URL.self, action: handleDrop, isTargeted: setDropTargeted)
        .overlay {
            if isDropTargeted, !(store?.batches.isEmpty ?? true) {
                // Empty state já tem visual de drop zone permanente — overlay
                // só faz sentido por cima da lista populada.
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentImportSheet(file: nil)
                } label: {
                    Label("Nova importação", systemImage: AppIcon.add.systemImage)
                }
                .help("Importar extrato bancário (OFX ou CSV)")
            }
        }
    }

    private var importsSubtitle: String {
        guard let store, !store.batches.isEmpty else { return "" }
        let count = store.batches.count
        return "\(count) \(count == 1 ? "importação" : "importações")"
    }

    @ViewBuilder
    private func content(store: ImportStore) -> some View {
        if store.batches.isEmpty {
            EmptyStateDropZone(
                isHighlighted: isDropTargeted,
                onBrowse: { presentImportSheet(file: nil) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .granaPagePadding()
        } else {
            list(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }

    private func list(store: ImportStore) -> some View {
        let rows = presentationRows(for: store.batches, store: store)
        let selectedRow = selectedRow(in: rows)

        return ImportHistoryReviewDeskView(
            rows: rows,
            selectedRow: selectedRow,
            selectedBatchId: selectedRow?.id,
            onSelect: { selectedBatchId = $0 },
            onUndo: { pendingDeleteBatch = $0 }
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

    private func selectedRow(
        in rows: [ImportHistoryBatchPresentation]
    ) -> ImportHistoryBatchPresentation? {
        if let selectedBatchId,
           let selected = rows.first(where: { $0.id == selectedBatchId }) {
            return selected
        }
        return rows.first
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

    // MARK: - Drop handling

    private func presentImportSheet(file: URL?) {
        // Atribuição única → `.sheet(item:)` abre com o `file` já capturado
        // dentro do contexto. Sem race entre flag de presença e URL.
        importContext = ImportContext(file: file)
    }

    /// Callback do `.dropDestination`. Roda no main actor. Valida extensão e
    /// abre a sheet com o arquivo pré-carregado; arquivos inválidos viram
    /// toast pelo `NoticeCenter` (sem abrir sheet — não faz sentido entrar no
    /// wizard pra logo cair em failed).
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

        // Múltiplos arquivos: avisa que vamos importar só o primeiro. O wizard
        // é single-file por design (uma instituição/conta por vez no preview).
        // Vira `.info` (não `.error`): nada falhou, só estamos explicando que
        // o input foi reduzido.
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

    var importedAtText: String {
        batch.importedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct ImportHistoryReviewDeskView: View {
    let rows: [ImportHistoryBatchPresentation]
    let selectedRow: ImportHistoryBatchPresentation?
    let selectedBatchId: UUID?
    let onSelect: (UUID) -> Void
    let onUndo: (ImportBatch) -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                reviewDeskHeader

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            ImportHistoryReviewDeskRow(
                                row: row,
                                isSelected: selectedBatchId == row.id,
                                onSelect: { onSelect(row.id) }
                            )
                        }
                    }
                }
            }
            .granaSurface(.solid, cornerRadius: GranaTheme.Radius.panel)
            .clipShape(RoundedRectangle(cornerRadius: GranaTheme.Radius.panel, style: .continuous))

            VStack(alignment: .leading, spacing: 14) {
                ImportHistoryDropPanel()
                if let selectedRow {
                    ImportHistorySelectedPanel(
                        row: selectedRow,
                        onUndo: { onUndo(selectedRow.batch) }
                    )
                }
            }
            .frame(width: 310)
            .padding(.leading, 16)
        }
        .granaPagePadding()
    }

    private var reviewDeskHeader: some View {
        HStack(spacing: 12) {
            Text("Instituição")
                .frame(width: 132, alignment: .leading)
            Text("Arquivo")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Conta")
                .frame(width: 180, alignment: .leading)
            Text("Linhas")
                .frame(width: 72, alignment: .trailing)
            Text("Data")
                .frame(width: 116, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(GranaTheme.Palette.muted)
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(GranaTheme.Palette.paper.opacity(0.55))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GranaTheme.Palette.line)
                .frame(height: 1)
        }
    }
}

private struct ImportHistoryReviewDeskRow: View {
    let row: ImportHistoryBatchPresentation
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    InstitutionIcon(kind: row.institutionKind, size: 28)
                    Text(row.institutionName)
                        .lineLimit(1)
                }
                .frame(width: 132, alignment: .leading)

                Text(row.batch.sourceFilename)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(row.accountName)
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)

                Text("\(row.batch.rowCount)")
                    .font(GranaTheme.Typography.number(size: 13, weight: .semibold))
                    .frame(width: 72, alignment: .trailing)

                Text(row.importedAtText)
                    .font(GranaTheme.Typography.number(size: 12, weight: .semibold))
                    .foregroundStyle(GranaTheme.Palette.muted)
                    .frame(width: 116, alignment: .trailing)
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(isSelected ? GranaTheme.Palette.teal.opacity(0.09) : .clear)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(GranaTheme.Palette.line)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ImportHistorySelectedPanel: View {
    let row: ImportHistoryBatchPresentation
    let onUndo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                InstitutionIcon(kind: row.institutionKind, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lote selecionado")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(GranaTheme.Palette.muted)
                    Text(row.institutionName)
                        .font(.system(size: 16, weight: .bold))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ImportHistoryDetailLine("Arquivo", row.batch.sourceFilename)
                ImportHistoryDetailLine("Conta", row.accountName)
                ImportHistoryDetailLine("Importado", row.importedAtText)
                ImportHistoryDetailLine("Formato", row.formatName)
            }

            Button(role: .destructive, action: onUndo) {
                Label("Desfazer lote", systemImage: AppIcon.undo.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GranaSecondaryButtonStyle())
            .foregroundStyle(GranaTheme.Palette.red)
        }
        .padding(16)
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.panel)
    }
}

private struct ImportHistoryDropPanel: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: AppIcon.importFile.systemImage)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(GranaTheme.Palette.teal)
            Text("Solte o próximo extrato")
                .font(.system(size: 15, weight: .bold))
            Text("A mesa deixa a próxima ação visível sem tirar densidade da lista.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GranaTheme.Palette.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GranaTheme.Palette.teal.opacity(0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    GranaTheme.Palette.teal.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 6])
                )
        }
    }
}

private struct ImportHistoryDetailLine: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(GranaTheme.Palette.muted)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
        }
    }
}

// MARK: - Empty state drop zone

/// Empty state da tela de Importações. Diferente de um `ContentUnavailableView`
/// genérico, ele é **o próprio drop target visual** — borda tracejada
/// permanente que se destaca durante o drag-over pra reforçar que arrastar
/// arquivos funciona aqui.
///
/// **Por que não deriva de `EmptyStateView`:** não é um anúncio passivo de
/// vazio — é um drop target interativo com animação e highlight de drag-over,
/// que precisa de vocabulário visual próprio (`symbolEffect`, stroke animado,
/// fill que reage ao `isTargeted`). Caber isso no `EmptyStateView` diluiria
/// as duas APIs.
private struct EmptyStateDropZone: View {
    let isHighlighted: Bool
    let onBrowse: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(isHighlighted ? 0.18 : 0.10))
                    .frame(width: 84, height: 84)
                Image(systemName: AppIcon.importFile.systemImage)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Color.primary)
                    .symbolEffect(.bounce, value: isHighlighted)
            }

            VStack(spacing: 6) {
                Text(isHighlighted ? "Solte para importar" : "Arraste e solte para importar")
                    .font(.title3.weight(.semibold))
                    .contentTransition(.opacity)
                Text("Aceita OFX (extrato bancário) ou CSV (fatura Inter). Um arquivo por vez.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            HStack(spacing: 10) {
                Text("ou")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button {
                    onBrowse()
                } label: {
                    Label("Selecionar arquivo", systemImage: AppIcon.importFile.systemImage)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(isHighlighted ? 0.06 : 0.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(isHighlighted ? 0.85 : 0.35),
                    style: StrokeStyle(lineWidth: isHighlighted ? 2 : 1.5, dash: [8, 6])
                )
        )
        .scaleEffect(isHighlighted ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.18), value: isHighlighted)
    }
}

// MARK: - Drop overlay (lista populada)

/// Overlay translúcido que aparece por cima da lista durante o drag-over.
/// Mesma linguagem visual do empty state pra continuidade — o usuário sabe
/// que está soltando "no mesmo lugar" independente do estado da tela.
private struct DropOverlay: View {
    var body: some View {
        ZStack {
            // Material translúcido suaviza o conteúdo embaixo sem escondê-lo
            // por completo — HIG: feedback claro mas não destrutivo.
            Rectangle()
                .fill(.regularMaterial)
                .opacity(0.9)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: 96, height: 96)
                    Image(systemName: AppIcon.importFile.systemImage)
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(Color.primary)
                }
                Text("Solte para importar")
                    .font(.title2.weight(.semibold))
                Text("OFX ou CSV")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(0.7),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
            )
            .padding(40)
        }
    }
}
