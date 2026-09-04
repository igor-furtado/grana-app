import ComposableArchitecture
import SwiftUI
import AppUI

struct AccountListView: View {
    @Bindable var store: StoreOf<AccountListFeature>
    @State private var sortOrder = [
        KeyPathComparator(\AccountListItem.displayName),
    ]

    var body: some View {
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
                .width(min: 210, ideal: 210, max: 240)

                TableColumn("Conta", value: \.displayName) { item in
                    Text(item.displayName)
                        .font(AppUI.Theme.Typography.subheadline)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
                        .lineLimit(1)
                }
                .width(min: 210, ideal: 210, max: 240)

                TableColumn("Saldo", value: \.currentBalance) { item in
                    Text(item.currentBalance.formatted(.currency(code: item.account.currency)))
                        .font(AppUI.Theme.Typography.moneySubheadline)
                        .foregroundStyle(item.currentBalance < 0 ? AppUI.Theme.Palette.red : AppUI.Theme.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                TableColumn("Status", value: \.statusRank) { item in
                    Text(item.statusText)
                        .font(AppUI.Theme.Typography.caption1Emphasis)
                        .foregroundStyle(item.account.archived ? AppUI.Theme.Palette.muted : AppUI.Theme.Palette.tealDeep)
                }
                .width(min: 60, ideal: 60, max: 60)

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
                .width(min: 80, ideal: 80, max: 80)
            } filterBar: {
                AccountListFilterBar(store: store)
            }
    }
}

private struct AccountListFilterBar: View {
    @Bindable var store: StoreOf<AccountListFeature>

    var body: some View {
        AppUI.TableFilterBar {
            AppUI.Selector(
                options: store.availableInstitutionNames.map { .init(id: $0, title: $0) },
                selection: $store.institutionFilter,
                icon: "building.columns"
            )
            .frame(width: 220, alignment: .leading)

            AppUI.TextField(
                text: $store.searchText,
                placeholder: "Buscar conta ou instituição",
                leadingSystemImage: "magnifyingglass",
                showsClearButton: true,
                font: AppUI.Theme.Typography.footnoteEmphasis,
                textAlignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
