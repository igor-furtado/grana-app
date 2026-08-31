import ComposableArchitecture
import SwiftUI

struct AccountListView: View {
    @Bindable var store: StoreOf<AccountListFeature>
    @State private var sortOrder = [
        KeyPathComparator(\AccountListItem.displayName),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.none) {
            panelHeader

            AppUI.Table(store.visibleItems, sortOrder: $sortOrder) {
                TableColumn("Instituição", value: \.institutionName) { item in
                    HStack(spacing: GranaTheme.Spacing.sm) {
                        InstitutionIcon(kind: item.institutionKind, size: 24)
                        Text(item.institutionName)
                            .font(GranaTheme.Typography.subheadlineEmphasis)
                            .foregroundStyle(GranaTheme.Palette.ink)
                            .lineLimit(1)
                    }
                }
                .width(min: 180, ideal: 220, max: 280)

                TableColumn("Conta", value: \.displayName) { item in
                    Text(item.displayName)
                        .font(GranaTheme.Typography.subheadline)
                        .foregroundStyle(GranaTheme.Palette.ink)
                        .lineLimit(1)
                }
                .width(min: 220, ideal: 300)

                TableColumn("Saldo", value: \.currentBalance) { item in
                    Text(item.currentBalance.formatted(.currency(code: item.account.currency)))
                        .font(GranaTheme.Typography.moneySubheadline)
                        .foregroundStyle(item.currentBalance < 0 ? GranaTheme.Palette.red : GranaTheme.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 120, ideal: 150, max: 180)

                TableColumn("Status", value: \.statusRank) { item in
                    Text(item.statusText)
                        .font(GranaTheme.Typography.caption1Emphasis)
                        .foregroundStyle(item.account.archived ? GranaTheme.Palette.muted : GranaTheme.Palette.tealDeep)
                }
                .width(min: 92, ideal: 110, max: 132)

                TableColumn("Ações") { item in
                    HStack(spacing: GranaTheme.Spacing.sm) {
                        Button {
                            store.send(.editButtonTapped(item.id))
                        } label: {
                            Image(systemName: AppIcon.edit.systemImage)
                                .foregroundStyle(GranaTheme.Palette.muted)
                        }
                        .buttonStyle(.borderless)
                        .help("Editar conta")

                        Button {
                            store.send(.archiveButtonTapped(item.id))
                        } label: {
                            Image(
                                systemName: item.account.archived
                                    ? AppIcon.unarchive.systemImage
                                    : AppIcon.archive.systemImage
                            )
                            .foregroundStyle(GranaTheme.Palette.muted)
                        }
                        .buttonStyle(.borderless)
                        .help(item.account.archived ? "Desarquivar conta" : "Arquivar conta")

                        Button(role: .destructive) {
                            store.send(.deleteButtonTapped(item.id))
                        } label: {
                            Image(systemName: AppIcon.delete.systemImage)
                                .foregroundStyle(GranaTheme.Palette.muted)
                        }
                        .buttonStyle(.borderless)
                        .help("Apagar conta")
                    }
                }
                .width(min: 118, ideal: 132, max: 156)
            } filterBar: {
                AccountListFilterBar(store: store)
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

            Text("\(store.visibleItems.count) conta\(store.visibleItems.count == 1 ? "" : "s")")
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
}

private struct AccountListFilterBar: View {
    @Bindable var store: StoreOf<AccountListFeature>

    var body: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.sm) {
            AppUI.Selector(
                label: "Instituição",
                options: store.availableInstitutionNames.map { .init(id: $0, title: $0) },
                selection: $store.institutionFilter,
                icon: "building.columns"
            )
            .frame(width: 220, alignment: .leading)

            AppUI.TextField(
                label: "Buscar conta",
                text: $store.searchText,
                placeholder: "Buscar conta ou instituição",
                leadingSystemImage: "magnifyingglass",
                showsClearButton: true,
                font: GranaTheme.Typography.footnoteEmphasis,
                textAlignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            AppUI.Toggle(
                label: "Mostrar arquivadas",
                isOn: $store.showArchived
            )
            .toggleStyle(.switch)
            .frame(width: 180, alignment: .leading)
            .frame(height: 40)
        }
    }
}
