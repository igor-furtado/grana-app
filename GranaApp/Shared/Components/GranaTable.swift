import SwiftUI

/// Wrapper fino sobre `SwiftUI.Table` para concentrar o shell visual padrão do
/// tema nas tabelas densas do app.
struct GranaTable<RowValue: Identifiable, Sort: SortComparator, FilterBar: View, Columns: TableColumnContent>: View
    where
    Columns.TableRowValue == RowValue,
    Columns.TableColumnSortComparator == Sort,
    Sort.Compared == RowValue
{
    private enum Selection {
        case single(Binding<RowValue.ID?>)
        case multiple(Binding<Set<RowValue.ID>>)
    }

    private let rows: [RowValue]
    private let selection: Selection
    private let sortOrder: Binding<[Sort]>?
    private let columns: Columns
    private let hasFilterBar: Bool
    private let filterBar: FilterBar

    init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        sortOrder: Binding<[Sort]>? = nil,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns,
        @ViewBuilder filterBar: () -> FilterBar
    ) {
        self.rows = rows
        self.selection = .single(selection)
        self.sortOrder = sortOrder
        self.columns = columns()
        self.hasFilterBar = true
        self.filterBar = filterBar()
    }

    init(
        _ rows: [RowValue],
        selection: Binding<Set<RowValue.ID>>,
        sortOrder: Binding<[Sort]>? = nil,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns,
        @ViewBuilder filterBar: () -> FilterBar
    ) {
        self.rows = rows
        self.selection = .multiple(selection)
        self.sortOrder = sortOrder
        self.columns = columns()
        self.hasFilterBar = true
        self.filterBar = filterBar()
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

            table
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GranaTheme.Palette.paper.opacity(0.42))
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var table: some View {
        switch selection {
        case let .single(selection):
            Table(rows, selection: selection, sortOrder: resolvedSortOrder) {
                columns
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)

        case let .multiple(selection):
            Table(rows, selection: selection, sortOrder: resolvedSortOrder) {
                columns
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
        }
    }

    private var resolvedSortOrder: Binding<[Sort]> {
        sortOrder ?? .constant([])
    }
}

extension GranaTable where FilterBar == EmptyView {
    init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        sortOrder: Binding<[Sort]>? = nil,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns
    ) {
        self.init(
            rows,
            selection: selection,
            sortOrder: sortOrder,
            columns: columns
        ) {
            EmptyView()
        }
    }

    init(
        _ rows: [RowValue],
        selection: Binding<Set<RowValue.ID>>,
        sortOrder: Binding<[Sort]>? = nil,
        @TableColumnBuilder<RowValue, Sort> columns: () -> Columns
    ) {
        self.init(
            rows,
            selection: selection,
            sortOrder: sortOrder,
            columns: columns
        ) {
            EmptyView()
        }
    }
}

extension GranaTable where Sort == Never, FilterBar == EmptyView {
    init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns
    ) {
        self.init(rows, selection: selection, sortOrder: nil, columns: columns)
    }

    init(
        _ rows: [RowValue],
        selection: Binding<Set<RowValue.ID>>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns
    ) {
        self.init(rows, selection: selection, sortOrder: nil, columns: columns)
    }
}

extension GranaTable where Sort == Never {
    init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns,
        @ViewBuilder filterBar: () -> FilterBar
    ) {
        self.init(rows, selection: selection, sortOrder: nil, columns: columns, filterBar: filterBar)
    }

    init(
        _ rows: [RowValue],
        selection: Binding<Set<RowValue.ID>>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns,
        @ViewBuilder filterBar: () -> FilterBar
    ) {
        self.init(rows, selection: selection, sortOrder: nil, columns: columns, filterBar: filterBar)
    }
}
