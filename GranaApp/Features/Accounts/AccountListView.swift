import ComposableArchitecture
import SwiftUI
import AppUI

struct AccountListView: View {
    @Bindable var store: StoreOf<AccountListFeature>
    @State private var sortOrder = [
        KeyPathComparator(\AccountListItem.displayName),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.none) {
            panelHeader

            AppUI.Table(store.visibleItems, sortOrder: $sortOrder) {
                TableColumn("Instituição", value: \.institutionName) { item in
                    HStack(spacing: AppUI.Theme.Spacing.sm) {
                        InstitutionIcon(kind: item.institutionKind, size: 24)
                        Text(item.institutionName)
                            .font(AppUI.Theme.Typography.subheadlineEmphasis)
                            .foregroundStyle(AppUI.Theme.Palette.ink)
                            .lineLimit(1)
                    }
                }
                .width(min: 180, ideal: 220, max: 280)

                TableColumn("Conta", value: \.displayName) { item in
                    Text(item.displayName)
                        .font(AppUI.Theme.Typography.subheadline)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
                        .lineLimit(1)
                }
                .width(min: 220, ideal: 300)

                TableColumn("Saldo", value: \.currentBalance) { item in
                    Text(item.currentBalance.formatted(.currency(code: item.account.currency)))
                        .font(AppUI.Theme.Typography.moneySubheadline)
                        .foregroundStyle(item.currentBalance < 0 ? AppUI.Theme.Palette.red : AppUI.Theme.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 120, ideal: 150, max: 180)

                TableColumn("Status", value: \.statusRank) { item in
                    Text(item.statusText)
                        .font(AppUI.Theme.Typography.caption1Emphasis)
                        .foregroundStyle(item.account.archived ? AppUI.Theme.Palette.muted : AppUI.Theme.Palette.tealDeep)
                }
                .width(min: 92, ideal: 110, max: 132)

                TableColumn("Ações") { item in
                    HStack(spacing: AppUI.Theme.Spacing.sm) {
                        Button {
                            store.send(.editButtonTapped(item.id))
                        } label: {
                            Image(systemName: AppUI.Icon.edit.systemImage)
                                .foregroundStyle(AppUI.Theme.Palette.muted)
                        }
                        .buttonStyle(.borderless)
                        .help("Editar conta")

                        Button {
                            store.send(.archiveButtonTapped(item.id))
                        } label: {
                            Image(
                                systemName: item.account.archived
                                    ? AppUI.Icon.unarchive.systemImage
                                    : AppUI.Icon.archive.systemImage
                            )
                            .foregroundStyle(AppUI.Theme.Palette.muted)
                        }
                        .buttonStyle(.borderless)
                        .help(item.account.archived ? "Desarquivar conta" : "Arquivar conta")

                        Button(role: .destructive) {
                            store.send(.deleteButtonTapped(item.id))
                        } label: {
                            Image(systemName: AppUI.Icon.delete.systemImage)
                                .foregroundStyle(AppUI.Theme.Palette.muted)
                        }
                        .buttonStyle(.borderless)
                        .help("Apagar conta")
                    }
                }
                .width(min: 118, ideal: 132, max: 156)
            } filterBar: {
                AccountListFilterBar(store: store)
            }
            .padding(AppUI.Theme.Spacing.md)
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .center, spacing: AppUI.Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: AppUI.Theme.Spacing.xxs) {
                Text("Contas acompanhadas")
                    .font(AppUI.Theme.Typography.headline)
                    .foregroundStyle(AppUI.Theme.Palette.ink)
                Text("Selecione uma conta para revisar o saldo atual e operar ações administrativas.")
                    .font(AppUI.Theme.Typography.footnote)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }

            Spacer(minLength: AppUI.Theme.Spacing.none)

            Text("\(store.visibleItems.count) conta\(store.visibleItems.count == 1 ? "" : "s")")
                .font(AppUI.Theme.Typography.caption1Emphasis)
                .foregroundStyle(AppUI.Theme.Palette.tealDeep)
                .padding(.horizontal, AppUI.Theme.Spacing.sm)
                .padding(.vertical, AppUI.Theme.Spacing.xs)
                .background(AppUI.Theme.Palette.teal.opacity(0.10), in: Capsule())
        }
        .padding(AppUI.Theme.Spacing.md)
        .background(AppUI.Theme.Palette.paper.opacity(0.58))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppUI.Theme.Palette.line)
                .frame(height: 1)
        }
    }
}

private struct AccountListFilterBar: View {
    @Bindable var store: StoreOf<AccountListFeature>

    var body: some View {
        AppUI.TableFilterBar {
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
                font: AppUI.Theme.Typography.footnoteEmphasis,
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
