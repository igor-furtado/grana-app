import SwiftUI

/// Wrapper fino sobre `SwiftUI.Table` para concentrar o shell visual padrão do
/// tema nas tabelas densas do app.
public struct TableFilterBar<Content: View>: View {
    @ViewBuilder private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            content()
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.paper.opacity(0.58))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.Palette.line)
                .frame(height: 1)
        }
    }

}

public struct Table<RowValue: Identifiable, Sort: SortComparator, FilterBar: View, Columns: TableColumnContent>: View
    where Columns.TableRowValue == RowValue,
    Columns.TableColumnSortComparator == Sort {
    private let hasFilterBar: Bool
    private let filterBar: FilterBar
    private let tableView: AnyView

    private init(
        tableView: AnyView,
        hasFilterBar: Bool,
        filterBar: FilterBar
    ) {
        self.tableView = tableView
        self.hasFilterBar = hasFilterBar
        self.filterBar = filterBar
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.none) {
            if hasFilterBar {
                filterBar
            }

            tableView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Palette.paper.opacity(0.42))
        .granaSurface(.solid, cornerRadius: Theme.Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

private extension Table {
    enum TableSelection {
        case none
        case single(Binding<RowValue.ID?>)
        case multiple(Binding<Set<RowValue.ID>>)
    }
}

private extension Table where Sort.Compared == RowValue {
    static func makeSortableTable(
        rows: [RowValue],
        selection: TableSelection,
        sortOrder: Binding<[Sort]>,
        columns: Columns
    ) -> AnyView {
        AnyView(
            Group {
                switch selection {
                case .none:
                    SwiftUI.Table(rows, sortOrder: sortOrder) {
                        columns
                    }
                case let .single(selection):
                    SwiftUI.Table(rows, selection: selection, sortOrder: sortOrder) {
                        columns
                    }
                case let .multiple(selection):
                    SwiftUI.Table(rows, selection: selection, sortOrder: sortOrder) {
                        columns
                    }
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
        )
    }
}

private extension Table where Sort == Never {
    static func makePlainTable(
        rows: [RowValue],
        selection: TableSelection,
        columns: Columns
    ) -> AnyView {
        AnyView(
            Group {
                switch selection {
                case .none:
                    SwiftUI.Table(of: RowValue.self) {
                        columns
                    } rows: {
                        ForEach(rows) { row in
                            TableRow(row)
                        }
                    }
                case let .single(selection):
                    SwiftUI.Table(of: RowValue.self, selection: selection) {
                        columns
                    } rows: {
                        ForEach(rows) { row in
                            TableRow(row)
                        }
                    }
                case let .multiple(selection):
                    SwiftUI.Table(of: RowValue.self, selection: selection) {
                        columns
                    } rows: {
                        ForEach(rows) { row in
                            TableRow(row)
                        }
                    }
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
        )
    }
}

extension Table where Sort.Compared == RowValue {
    public init(
        _ rows: [RowValue],
        sortOrder: Binding<[Sort]>,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns,
        @ViewBuilder filterBar: () -> FilterBar
    ) {
        self.init(
            tableView: Self.makeSortableTable(
                rows: rows,
                selection: .none,
                sortOrder: sortOrder,
                columns: columns()
            ),
            hasFilterBar: true,
            filterBar: filterBar()
        )
    }

    public init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        sortOrder: Binding<[Sort]>,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns,
        @ViewBuilder filterBar: () -> FilterBar
    ) {
        self.init(
            tableView: Self.makeSortableTable(
                rows: rows,
                selection: .single(selection),
                sortOrder: sortOrder,
                columns: columns()
            ),
            hasFilterBar: true,
            filterBar: filterBar()
        )
    }

    public init(
        _ rows: [RowValue],
        selection: Binding<Set<RowValue.ID>>,
        sortOrder: Binding<[Sort]>,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns,
        @ViewBuilder filterBar: () -> FilterBar
    ) {
        self.init(
            tableView: Self.makeSortableTable(
                rows: rows,
                selection: .multiple(selection),
                sortOrder: sortOrder,
                columns: columns()
            ),
            hasFilterBar: true,
            filterBar: filterBar()
        )
    }
}

extension Table where Sort.Compared == RowValue, FilterBar == EmptyView {
    public init(
        _ rows: [RowValue],
        sortOrder: Binding<[Sort]>,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns
    ) {
        self.init(rows, sortOrder: sortOrder, columns: columns) {
            EmptyView()
        }
    }

    public init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        sortOrder: Binding<[Sort]>,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns
    ) {
        self.init(rows, selection: selection, sortOrder: sortOrder, columns: columns) {
            EmptyView()
        }
    }

    public init(
        _ rows: [RowValue],
        selection: Binding<Set<RowValue.ID>>,
        sortOrder: Binding<[Sort]>,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns
    ) {
        self.init(rows, selection: selection, sortOrder: sortOrder, columns: columns) {
            EmptyView()
        }
    }
}

extension Table where Sort == Never {
    public init(
        _ rows: [RowValue],
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns,
        @ViewBuilder filterBar: () -> FilterBar
    ) {
        self.init(
            tableView: Self.makePlainTable(
                rows: rows,
                selection: .none,
                columns: columns()
            ),
            hasFilterBar: true,
            filterBar: filterBar()
        )
    }

    public init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns,
        @ViewBuilder filterBar: () -> FilterBar
    ) {
        self.init(
            tableView: Self.makePlainTable(
                rows: rows,
                selection: .single(selection),
                columns: columns()
            ),
            hasFilterBar: true,
            filterBar: filterBar()
        )
    }

    public init(
        _ rows: [RowValue],
        selection: Binding<Set<RowValue.ID>>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns,
        @ViewBuilder filterBar: () -> FilterBar
    ) {
        self.init(
            tableView: Self.makePlainTable(
                rows: rows,
                selection: .multiple(selection),
                columns: columns()
            ),
            hasFilterBar: true,
            filterBar: filterBar()
        )
    }
}

extension Table where Sort == Never, FilterBar == EmptyView {
    public init(
        _ rows: [RowValue],
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns
    ) {
        self.init(rows, columns: columns) {
            EmptyView()
        }
    }

    public init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns
    ) {
        self.init(rows, selection: selection, columns: columns) {
            EmptyView()
        }
    }

    public init(
        _ rows: [RowValue],
        selection: Binding<Set<RowValue.ID>>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns
    ) {
        self.init(rows, selection: selection, columns: columns) {
            EmptyView()
        }
    }
}
