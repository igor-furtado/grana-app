import ComposableArchitecture
import SwiftUI

struct CategorizationRowView: View {
    @Bindable var store: StoreOf<CategorizationFeature>
    let index: Int

    private var suggestion: CategorizationSuggestion {
        store.suggestions[index]
    }

    var body: some View {
        HStack(alignment: .center, spacing: GranaTheme.Spacing.sm) {
            if let kind = store.state.institutionKind(forAccountId: suggestion.transactionAccountId) {
                InstitutionIcon(kind: kind, size: 24)
            }

            Text(suggestion.transactionDescription)
                .font(GranaTheme.Typography.callout)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
                .help(suggestion.transactionDescription)

            categoryMenu
            subcategoryMenu

            VStack(alignment: .trailing, spacing: GranaTheme.Spacing.xxs) {
                Text(suggestion.transactionAmount.formatted(.currency(code: "BRL")))
                    .font(GranaTheme.Typography.moneySubheadline)
                    .foregroundStyle(amountColor)
                Text(GranaDateFormat.fullDate(suggestion.transactionOccurredAt))
                    .font(GranaTheme.Typography.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 132, alignment: .trailing)
        }
        .opacity(suggestion.isReviewed ? 0.6 : 1.0)
    }

    private var amountColor: Color {
        guard let category = store.state.category(for: suggestion.categoryId) else {
            return .primary
        }
        switch category.kind {
        case .income: return .income
        case .transfer: return .transfer
        case .expense: return .primary
        }
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(store.rootCategories) { category in
                Button(category.name) {
                    store.send(
                        .applyCorrection(
                            index: index,
                            categoryId: category.id,
                            subcategoryId: nil
                        )
                    )
                }
            }
        } label: {
            menuLabel(text: rootName)
        }
        .menuStyle(.borderlessButton)
        .frame(minWidth: 130, maxWidth: .infinity)
        .help(rootName)
    }

    private var subcategoryMenu: some View {
        Menu {
            Button("Nenhuma") {
                store.send(
                    .applyCorrection(
                        index: index,
                        categoryId: suggestion.categoryId,
                        subcategoryId: nil
                    )
                )
            }
            ForEach(store.state.subcategories(of: suggestion.categoryId)) { subcategory in
                Button(subcategory.name) {
                    store.send(
                        .applyCorrection(
                            index: index,
                            categoryId: suggestion.categoryId,
                            subcategoryId: subcategory.id
                        )
                    )
                }
            }
        } label: {
            menuLabel(text: subName ?? "—")
        }
        .menuStyle(.borderlessButton)
        .frame(minWidth: 110, maxWidth: .infinity)
        .help(subName ?? "Sem subcategoria")
    }

    private var rootName: String {
        store.state.category(for: suggestion.categoryId)?.name ?? "Categoria"
    }

    private var subName: String? {
        guard let subcategoryId = suggestion.subcategoryId else { return nil }
        return store.state.category(for: subcategoryId)?.name
    }

    private func menuLabel(text: String) -> some View {
        HStack(spacing: GranaTheme.Spacing.xxs) {
            Text(text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: AppIcon.sort.systemImage)
                .font(.system(size: GranaTheme.IconSize.micro))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, GranaTheme.Spacing.xs)
        .padding(.vertical, GranaTheme.Spacing.xxs)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
