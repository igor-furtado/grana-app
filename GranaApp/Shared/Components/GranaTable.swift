import SwiftUI

/// Wrapper fino sobre `SwiftUI.Table` para concentrar o shell visual padrão do
/// tema nas tabelas densas do app.
struct GranaTable<RowValue: Identifiable, Sort: SortComparator, FilterBar: View, Columns: TableColumnContent>: View
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

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            if hasFilterBar {
                filterBar
                    .padding(GranaTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GranaTheme.Palette.paper.opacity(0.58))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(GranaTheme.Palette.line)
                            .frame(height: 1)
                    }
            }

            tableView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GranaTheme.Palette.paper.opacity(0.42))
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous))
    }
}

private extension GranaTable {
    enum TableSelection {
        case none
        case single(Binding<RowValue.ID?>)
        case multiple(Binding<Set<RowValue.ID>>)
    }
}

private extension GranaTable where Sort.Compared == RowValue {
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
                    Table(rows, sortOrder: sortOrder) {
                        columns
                    }
                case let .single(selection):
                    Table(rows, selection: selection, sortOrder: sortOrder) {
                        columns
                    }
                case let .multiple(selection):
                    Table(rows, selection: selection, sortOrder: sortOrder) {
                        columns
                    }
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
        )
    }
}

private extension GranaTable where Sort == Never {
    static func makePlainTable(
        rows: [RowValue],
        selection: TableSelection,
        columns: Columns
    ) -> AnyView {
        AnyView(
            Group {
                switch selection {
                case .none:
                    Table(of: RowValue.self) {
                        columns
                    } rows: {
                        ForEach(rows) { row in
                            TableRow(row)
                        }
                    }
                case let .single(selection):
                    Table(of: RowValue.self, selection: selection) {
                        columns
                    } rows: {
                        ForEach(rows) { row in
                            TableRow(row)
                        }
                    }
                case let .multiple(selection):
                    Table(of: RowValue.self, selection: selection) {
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

extension GranaTable where Sort.Compared == RowValue {
    init(
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

    init(
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

    init(
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

extension GranaTable where Sort.Compared == RowValue, FilterBar == EmptyView {
    init(
        _ rows: [RowValue],
        sortOrder: Binding<[Sort]>,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns
    ) {
        self.init(rows, sortOrder: sortOrder, columns: columns) {
            EmptyView()
        }
    }

    init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        sortOrder: Binding<[Sort]>,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns
    ) {
        self.init(rows, selection: selection, sortOrder: sortOrder, columns: columns) {
            EmptyView()
        }
    }

    init(
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

extension GranaTable where Sort == Never {
    init(
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

    init(
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

    init(
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

extension GranaTable where Sort == Never, FilterBar == EmptyView {
    init(
        _ rows: [RowValue],
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns
    ) {
        self.init(rows, columns: columns) {
            EmptyView()
        }
    }

    init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns
    ) {
        self.init(rows, selection: selection, columns: columns) {
            EmptyView()
        }
    }

    init(
        _ rows: [RowValue],
        selection: Binding<Set<RowValue.ID>>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns
    ) {
        self.init(rows, selection: selection, columns: columns) {
            EmptyView()
        }
    }
}
