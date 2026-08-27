import ComposableArchitecture
import SwiftUI

struct TransactionFormView: View {
    @Bindable var store: StoreOf<TransactionFormFeature>

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            Form {
                TextField(
                    "Descrição",
                    text: $store.description,
                    prompt: Text("Ex: Almoço no restaurante")
                )

                LabeledContent("Valor") {
                    CurrencyField(cents: $store.amountCents)
                }

                Picker("Conta", selection: $store.accountId) {
                    ForEach(store.state.sourceAccountOptions) { account in
                        Text(store.state.displayName(for: account)).tag(UUID?.some(account.id))
                    }
                }

                Picker("Categoria", selection: $store.categoryId) {
                    ForEach(store.state.rootCategories) { category in
                        Text(category.name).tag(UUID?.some(category.id))
                    }
                }

                if let categoryId = store.categoryId,
                   !store.state.subcategories(of: categoryId).isEmpty
                {
                    Picker("Subcategoria", selection: $store.subcategoryId) {
                        Text("(nenhuma)").tag(UUID?.none)
                        ForEach(store.state.subcategories(of: categoryId)) { sub in
                            Text(sub.name).tag(UUID?.some(sub.id))
                        }
                    }
                }

                if store.selectedCategoryKind == .transfer {
                    Picker("Conta de destino", selection: $store.destinationAccountId) {
                        Text("(nenhuma)").tag(UUID?.none)
                        ForEach(store.state.destinationAccountOptions) { account in
                            Text(store.state.displayName(for: account)).tag(UUID?.some(account.id))
                        }
                    }
                }

                if store.supportsAdvancedCardRules,
                   store.selectedAccountIsCreditCard,
                   store.selectedCategoryKind != .transfer
                {
                    refundSection
                }

                if store.supportsAdvancedCardRules, store.isPayingCreditCard {
                    statementPaymentSection
                }

                DatePicker("Data", selection: $store.occurredAt, displayedComponents: [.date])
                DatePicker("Hora", selection: $store.occurredAt, displayedComponents: [.hourAndMinute])

                LabeledContent("Notas") {
                    ZStack(alignment: .topLeading) {
                        if store.notes.isEmpty {
                            Text("Opcional")
                                .foregroundStyle(.tertiary)
                                .padding(.top, GranaTheme.Spacing.xs)
                                .padding(.leading, GranaTheme.Spacing.xxs)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $store.notes)
                            .frame(minHeight: 80, maxHeight: 160)
                            .scrollContentBackground(.hidden)
                    }
                }

                if let saveError = store.saveError {
                    Text(saveError)
                        .foregroundStyle(.danger)
                        .font(GranaTheme.Typography.callout)
                }
            }
            .formStyle(.grouped)

            BottomActionBar {
                Button("Cancelar") { store.send(.cancelButtonTapped) }
                Button("Salvar") { store.send(.saveButtonTapped) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canSave || store.isSaving)
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 680, idealWidth: 720, minHeight: 560)
        .alert("Prévia do recálculo", isPresented: $store.showsRetroactivePreview) {
            Button("Cancelar", role: .cancel) {}
            Button("Confirmar alteração") {
                store.send(.retroactivePreviewConfirmTapped)
            }
        } message: {
            Text(store.state.retroactivePreviewText)
        }
    }

    private var statementPaymentSection: some View {
        Section {
            if store.state.automaticPaymentPreview.isEmpty {
                Text("Nenhuma dívida elegível nessa data.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.state.automaticPaymentPreview, id: \.statement.id) { item in
                    LabeledContent(statementPickerLabel(item.statement)) {
                        Text(item.amount.formatted(.currency(code: "BRL")))
                            .font(GranaTheme.Typography.moneySubheadline)
                    }
                }
            }
        } header: {
            Text("Distribuição automática")
        } footer: {
            Text(
                "O valor será aplicado às dívidas elegíveis mais antigas. Excesso sobre uma fatura paga fica visível como pagamento excedente."
            )
        }
    }

    private var refundSection: some View {
        Section {
            Picker("Estorno de", selection: $store.refundOfTransactionId) {
                Text("Não é estorno").tag(UUID?.none)
                ForEach(store.state.refundablePurchases) { purchase in
                    Text(
                        "\(purchase.description) · \(store.state.remainingRefundableAmount(for: purchase).formatted(.currency(code: "BRL")))"
                    )
                    .tag(UUID?.some(purchase.id))
                }
            }
        } header: {
            Text("Estorno")
        } footer: {
            Text("Estornos herdam conta e categoria da compra e pertencem ao ciclo da própria data.")
        }
    }

    private func statementPickerLabel(_ statement: Statement) -> String {
        let monthYear = Self.statementMonthFormatter.string(from: statement.dueDate)
        let remaining = store.state.remainingAmount(of: statement)
        let total = statement.totalAmount
        let remainingStr = remaining.formatted(.currency(code: "BRL"))
        let totalStr = total.formatted(.currency(code: "BRL"))
        return "Fatura \(monthYear) · Faltam \(remainingStr) de \(totalStr)"
    }

    private static let statementMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM/yyyy"
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
