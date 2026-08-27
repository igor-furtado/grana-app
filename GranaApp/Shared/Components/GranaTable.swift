import SwiftUI

/// Wrapper fino sobre `SwiftUI.Table` para concentrar o shell visual padrão do
/// tema nas tabelas densas do app.
struct GranaTable<RowValue: Identifiable, Columns: TableColumnContent>: View where
    Columns.TableRowValue == RowValue,
    Columns.TableColumnSortComparator == Never
{
    private let rows: [RowValue]
    @Binding private var selection: RowValue.ID?
    private let columns: Columns

    init(
        _ rows: [RowValue],
        selection: Binding<RowValue.ID?>,
        @TableColumnBuilder<RowValue, Never> columns: () -> Columns
    ) {
        self.rows = rows
        _selection = selection
        self.columns = columns()
    }

    var body: some View {
        Table(rows, selection: $selection) {
            columns
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .scrollContentBackground(.hidden)
        .background(GranaTheme.Palette.paper.opacity(0.42))
        .granaSurface(.solid, cornerRadius: GranaTheme.Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: GranaTheme.Radius.card, style: .continuous))
    }
}
