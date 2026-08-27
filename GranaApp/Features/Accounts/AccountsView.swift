import Foundation
import SwiftUI

struct AccountsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: AccountStore?
    @State private var formMode: FormMode?
    @State private var showArchived = false
    @State private var selectedAccountId: UUID?
    @State private var showDeleteConfirm = false
    @State private var sortOrder = [
        KeyPathComparator(\AccountTableRow.displayName),
    ]
    @State private var institutionFilter: String = "Todas"
    @State private var searchText = ""

    /// `Identifiable` pra alimentar o `.sheet(item:)` — o id distingue
    /// "novo" de cada edição específica, garantindo que trocar de "editar
    /// conta A" pra "editar conta B" remonte o form (estado limpo).
    enum FormMode: Identifiable {
        case create
        case edit(Account)

        var id: String {
            switch self {
            case .create: return "create"
            case let .edit(account): return "edit-\(account.id.uuidString)"
            }
        }
    }

    var body: some View {
        Group {
            if let store {
                content(store: store)
                    .task { await store.load() }
            } else {
                ProgressView()
                    .task { store = AccountStore(container: environment.container) }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
    }

    private func content(store: AccountStore) -> some View {
        let allRows = allAccountRows(store: store)
        let rows = filteredRows(from: allRows)

        return VStack(spacing: GranaTheme.Spacing.sm) {
            header(store: store, visibleCount: rows.count)

            Group {
                if allRows.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    tableLayout(store: store, rows: rows)
                }
            }
        }
        .granaPagePadding()
        .sheet(item: $formMode) { mode in
            AccountFormView(
                existing: editingAccount(from: mode),
                lockedType: .checking,
                onCancel: { formMode = nil },
                onSaved: { formMode = nil }
            )
            .environment(store)
        }
        .confirmationDialog(
            "Apagar conta?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Apagar", role: .destructive) {
                guard let id = selectedAccountId else { return }
                Task {
                    do {
                        try await store.delete(id: id)
                    } catch {
                        NoticeCenter.shared.report(error)
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(
                "A conta só será apagada se não houver transações, faturas ou lotes de importação vinculados."
            )
        }
        .onChange(of: rows.map(\.id)) { _, ids in
            reconcileSelection(visibleIds: ids)
        }
    }

    private func header(store: AccountStore, visibleCount: Int) -> some View {
        FeatureScreenHeader(
            title: "Contas",
            subtitle: accountsSubtitle(store: store, visibleCount: visibleCount)
        ) {
            HStack(spacing: GranaTheme.Spacing.sm) {
                Button {
                    formMode = .create
                } label: {
                    Label("Nova conta", systemImage: AppIcon.add.systemImage)
                }
                .buttonStyle(GranaPrimaryButtonStyle())
            }
        }
    }

    private func tableLayout(store: AccountStore, rows: [AccountTableRow]) -> some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
            AccountsMainPanel(
                rows: rows,
                selectedAccountId: $selectedAccountId,
                sortOrder: $sortOrder,
                institutionFilter: $institutionFilter,
                searchText: $searchText,
                showArchived: $showArchived
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AccountsSidebar(
                row: selectedRow(in: rows),
                onEdit: {
                    guard let account = selectedRow(in: rows)?.account else { return }
                    formMode = .edit(account)
                },
                onToggleArchive: {
                    guard let account = selectedRow(in: rows)?.account else { return }
                    Task {
                        do {
                            try await store.setArchived(account, archived: !account.archived)
                        } catch {
                            NoticeCenter.shared.report(error)
                        }
                    }
                },
                onDelete: {
                    guard selectedRow(in: rows) != nil else { return }
                    showDeleteConfirm = true
                }
            )
            .frame(width: 320)
        }
    }

    private var hasArchivedAccount: Bool {
        store?.accounts.contains { $0.type == .checking && $0.archived } ?? false
    }

    private func accountsSubtitle(store: AccountStore, visibleCount: Int) -> String {
        let totalCount = store.accounts.filter { $0.type == .checking }.count
        if hasArchivedAccount {
            return showArchived
                ? "\(visibleCount) de \(totalCount) contas visíveis"
                : "\(visibleCount) contas ativas"
        }
        return "\(visibleCount) \(visibleCount == 1 ? "conta" : "contas")"
    }

    private func filteredRows(from rows: [AccountTableRow]) -> [AccountTableRow] {
        rows
            .filter { row in
                institutionFilter == "Todas" || row.institutionName == institutionFilter
            }
            .filter { row in
                searchText.isEmpty
                    || row.displayName.localizedCaseInsensitiveContains(searchText)
                    || row.institutionName.localizedCaseInsensitiveContains(searchText)
            }
            .sorted(using: sortOrder)
    }

    private func reconcileSelection(visibleIds: [UUID]) {
        guard let current = selectedAccountId, !visibleIds.contains(current) else { return }
        selectedAccountId = nil
    }

    private var emptyState: some View {
        EmptyStateView(
            "Sem contas por aqui",
            icon: .sidebarAccounts,
            description: "Cadastre as contas correntes que você usa (Inter, Nubank, XP, etc.) pra vincular transações e organizar suas movimentações."
        ) {
            Button {
                formMode = .create
            } label: {
                Label("Cadastrar primeira conta", systemImage: AppIcon.add.systemImage)
            }
            .buttonStyle(GranaPrimaryButtonStyle())
            .disabled(formMode != nil)
        }
    }

    private func allAccountRows(store: AccountStore) -> [AccountTableRow] {
        store.accounts.compactMap { account in
            guard account.type == .checking else { return nil }
            guard showArchived || !account.archived else { return nil }

            let institution = store.institution(forAccount: account)
            return AccountTableRow(
                account: account,
                displayName: store.displayName(for: account),
                institutionName: institution?.name ?? "Sem instituição",
                institutionKind: institution?.kind ?? .other,
                currentBalance: store.currentBalance(for: account)
            )
        }
    }

    private func selectedRow(in rows: [AccountTableRow]) -> AccountTableRow? {
        guard let selectedAccountId else { return nil }
        return rows.first(where: { $0.id == selectedAccountId })
    }

    private func editingAccount(from mode: FormMode) -> Account? {
        if case let .edit(account) = mode { return account }
        return nil
    }
}

private struct AccountTableRow: Identifiable {
    let account: Account
    let displayName: String
    let institutionName: String
    let institutionKind: InstitutionKind
    let currentBalance: Decimal

    var id: UUID {
        account.id
    }

    var statusText: String {
        account.archived ? "Arquivada" : "Ativa"
    }

    var statusRank: Int {
        account.archived ? 1 : 0
    }
}

private struct AccountsMainPanel: View {
    let rows: [AccountTableRow]
    @Binding var selectedAccountId: UUID?
    @Binding var sortOrder: [KeyPathComparator<AccountTableRow>]
    @Binding var institutionFilter: String
    @Binding var searchText: String
    @Binding var showArchived: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.none) {
            panelHeader

            GranaTable(rows, selection: $selectedAccountId, sortOrder: $sortOrder) {
                TableColumn("Instituição", value: \.institutionName) { (row: AccountTableRow) in
                    HStack(spacing: GranaTheme.Spacing.sm) {
                        InstitutionIcon(kind: row.institutionKind, size: 24)
                        Text(row.institutionName)
                            .font(GranaTheme.Typography.subheadlineEmphasis)
                            .foregroundStyle(GranaTheme.Palette.ink)
                            .lineLimit(1)
                    }
                }
                .width(min: 180, ideal: 220, max: 280)

                TableColumn("Conta", value: \.displayName) { (row: AccountTableRow) in
                    Text(row.displayName)
                        .font(GranaTheme.Typography.subheadline)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .lineLimit(1)
                }
                .width(min: 220, ideal: 300)

                TableColumn("Saldo", value: \.currentBalance) { (row: AccountTableRow) in
                    Text(row.currentBalance.formatted(.currency(code: row.account.currency)))
                        .font(GranaTheme.Typography.moneySubheadline)
                        .foregroundStyle(row.currentBalance < 0 ? GranaTheme.Palette.red : GranaTheme.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 120, ideal: 150, max: 180)

                TableColumn("Status", value: \.statusRank) { (row: AccountTableRow) in
                    Text(row.statusText)
                        .font(GranaTheme.Typography.caption1Emphasis)
                        .foregroundStyle(row.account.archived ? GranaTheme.Palette.muted : GranaTheme.Palette.tealDeep)
                }
                .width(min: 92, ideal: 110, max: 132)
            } filterBar: {
                AccountsFilterBar(
                    institutionOptions: institutionOptions,
                    institutionFilter: $institutionFilter,
                    searchText: $searchText,
                    showArchived: $showArchived
                )
            }
            .padding(GranaTheme.Spacing.md)
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .center, spacing: GranaTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                Text("Contas acompanhadas")
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.ink)
                Text("Selecione uma conta para revisar o saldo atual e operar ações administrativas.")
                    .font(GranaTheme.Typography.footnote)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }

            Spacer(minLength: GranaTheme.Spacing.none)

            Text("\(rows.count) conta\(rows.count == 1 ? "" : "s")")
                .font(GranaTheme.Typography.caption1Emphasis)
                .foregroundStyle(GranaTheme.Palette.tealDeep)
                .padding(.horizontal, GranaTheme.Spacing.sm)
                .padding(.vertical, GranaTheme.Spacing.xs)
                .background(GranaTheme.Palette.teal.opacity(0.10), in: Capsule())
        }
        .padding(GranaTheme.Spacing.md)
        .background(GranaTheme.Palette.paper.opacity(0.58))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GranaTheme.Palette.line)
                .frame(height: 1)
        }
    }

    private var institutionOptions: [String] {
        ["Todas"] + Array(Set(rows.map(\.institutionName))).sorted()
    }
}

private struct AccountsFilterBar: View {
    let institutionOptions: [String]
    @Binding var institutionFilter: String
    @Binding var searchText: String
    @Binding var showArchived: Bool

    var body: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                Text("Instituição")
                    .font(GranaTheme.Typography.caption2Emphasis)
                    .foregroundStyle(GranaTheme.Palette.muted)

                Menu {
                    ForEach(institutionOptions, id: \.self) { option in
                        Button(option) {
                            institutionFilter = option
                        }
                    }
                } label: {
                    filterChip(value: institutionFilter, icon: "building.columns")
                }
                .buttonStyle(.plain)
            }
            .frame(width: 220, alignment: .leading)

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                Text("Conta")
                    .font(GranaTheme.Typography.caption2Emphasis)
                    .foregroundStyle(GranaTheme.Palette.muted)

                HStack(spacing: GranaTheme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: GranaTheme.IconSize.small, weight: .semibold))
                        .foregroundStyle(GranaTheme.Palette.tealDeep)

                    TextField("Buscar conta ou instituição", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(GranaTheme.Typography.footnoteEmphasis)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(GranaTheme.Palette.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, GranaTheme.Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
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

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                Text("Status")
                    .font(GranaTheme.Typography.caption2Emphasis)
                    .foregroundStyle(GranaTheme.Palette.muted)

                Toggle(isOn: $showArchived) {
                    Text("Mostrar arquivadas")
                        .font(GranaTheme.Typography.footnoteEmphasis)
                        .foregroundStyle(GranaTheme.Palette.ink)
                }
                .toggleStyle(.switch)
                .frame(width: 180, alignment: .leading)
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

private struct AccountsSidebar: View {
    let row: AccountTableRow?
    let onEdit: () -> Void
    let onToggleArchive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if let row {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
                    InstitutionIcon(kind: row.institutionKind, size: 46)

                    VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
                        Text("Conta selecionada")
                            .font(GranaTheme.Typography.caption1Emphasis)
                            .foregroundStyle(GranaTheme.Palette.muted)
                        Text(row.displayName)
                            .font(GranaTheme.Typography.headline)
                            .foregroundStyle(GranaTheme.Palette.ink)
                        Text(row.institutionName)
                            .font(GranaTheme.Typography.footnote)
                            .foregroundStyle(GranaTheme.Palette.muted)
                    }
                }

                VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                    accountDetailLine(
                        "Saldo atual",
                        row.currentBalance.formatted(.currency(code: row.account.currency))
                    )
                    accountDetailLine("Status", row.statusText)
                    accountDetailLine("Moeda", row.account.currency)
                }

                Button(action: onEdit) {
                    Label("Editar conta", systemImage: AppIcon.edit.systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GranaPrimaryButtonStyle())

                Button(action: onToggleArchive) {
                    Label(
                        row.account.archived ? "Desarquivar conta" : "Arquivar conta",
                        systemImage: row.account.archived ? AppIcon.unarchive.systemImage : AppIcon.archive.systemImage
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GranaSecondaryButtonStyle())

                Button(role: .destructive, action: onDelete) {
                    Label("Apagar conta", systemImage: AppIcon.delete.systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GranaSecondaryButtonStyle())
                .foregroundStyle(GranaTheme.Palette.red)
            }
            .padding(GranaTheme.Spacing.md)
            .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
        } else {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                Text("Selecione uma conta")
                    .font(GranaTheme.Typography.headline)
                    .foregroundStyle(GranaTheme.Palette.ink)
                Text("A inspeção lateral concentra o saldo atual e as ações administrativas da conta.")
                    .font(GranaTheme.Typography.footnote)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }
            .padding(GranaTheme.Spacing.md)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
        }
    }

    private func accountDetailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
            Text(label)
                .font(GranaTheme.Typography.caption2Emphasis)
                .foregroundStyle(GranaTheme.Palette.muted)
            Text(value)
                .font(GranaTheme.Typography.footnoteEmphasis)
                .foregroundStyle(GranaTheme.Palette.ink)
                .lineLimit(2)
        }
    }
}
