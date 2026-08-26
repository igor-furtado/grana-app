import Foundation
import SwiftUI

/// Formulário de criação/edição de transação.
///
/// **Modo "novo" vs "edição":** o init aceita `Transaction?` — `nil` significa
/// novo registro. O título do sheet e o botão "Salvar" adaptam o
/// comportamento sem precisar de duas Views diferentes.
///
/// Pagamentos destinados a cartão são distribuídos automaticamente pelo
/// projetor, da dívida elegível mais antiga para a mais recente.
struct TransactionFormView: View {
    @Environment(TransactionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let existing: Transaction?

    @State private var description: String = ""
    /// Estilo "calculadora": guardamos o valor em **centavos** (Int) e
    /// formatamos pra BRL na exibição. Isso garante que o usuário digite só
    /// números e o "R$ X,YY" apareça automaticamente, sem precisar pensar em
    /// vírgula ou separador de milhar.
    @State private var amountCents: Int = 0
    @State private var occurredAt: Date = .init()
    @State private var accountId: UUID?
    @State private var categoryId: UUID?
    @State private var subcategoryId: UUID?
    /// Fase 4.5: contraparte quando a categoria selecionada é `transfer`.
    /// Aparece como picker logo abaixo do "Conta" — só renderizado quando
    /// `selectedCategoryKind == .transfer`. Ao trocar a categoria pra qualquer
    /// outro kind, o valor é limpo (`onChange` em `categoryId`).
    @State private var destinationAccountId: UUID?
    @State private var refundOfTransactionId: UUID?
    @State private var notes: String = ""
    @State private var saveError: String?
    @State private var showsRetroactivePreview = false

    init(existing: Transaction? = nil) {
        self.existing = existing
    }

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            SheetHeaderView(title: existing == nil ? "Nova transação" : "Editar transação")

            Form {
                // `prompt:` é o placeholder DENTRO do campo. O primeiro
                // argumento ("Descrição") é o LABEL que aparece à esquerda
                // do campo no Form do macOS.
                TextField(
                    "Descrição",
                    text: $description,
                    prompt: Text("Ex: Almoço no restaurante")
                )

                LabeledContent("Valor") {
                    CurrencyField(cents: $amountCents)
                }

                // Sem opção "Selecione" — o usuário escolhe da lista direto.
                // `accountId` é defaultado pra primeira conta em `loadExisting`.
                Picker("Conta", selection: $accountId) {
                    ForEach(sourceAccountOptions) { account in
                        Text(store.displayName(for: account)).tag(UUID?.some(account.id))
                    }
                }
                .onChange(of: accountId) { _, newValue in
                    if destinationAccountId == newValue {
                        destinationAccountId = nil
                    }
                    if !refundablePurchases.contains(where: { $0.id == refundOfTransactionId }) {
                        refundOfTransactionId = nil
                    }
                }

                Picker("Categoria", selection: $categoryId) {
                    ForEach(store.rootCategories) { category in
                        Text(category.name).tag(UUID?.some(category.id))
                    }
                }
                .onChange(of: categoryId) { oldValue, _ in
                    if oldValue != nil {
                        subcategoryId = nil
                        if selectedCategoryKind != .transfer {
                            destinationAccountId = nil
                        }
                    }
                }

                if let categoryId,
                   !store.subcategories(of: categoryId).isEmpty
                {
                    Picker("Subcategoria", selection: $subcategoryId) {
                        Text("(nenhuma)").tag(UUID?.none)
                        ForEach(store.subcategories(of: categoryId)) { sub in
                            Text(sub.name).tag(UUID?.some(sub.id))
                        }
                    }
                }

                if selectedCategoryKind == .transfer {
                    Picker("Conta de destino", selection: $destinationAccountId) {
                        Text("(nenhuma)").tag(UUID?.none)
                        ForEach(destinationAccountOptions) { account in
                            Text(store.displayName(for: account)).tag(UUID?.some(account.id))
                        }
                    }
                    .onChange(of: destinationAccountId) { _, _ in
                    }
                }

                if store.supportsAdvancedCardRules,
                   selectedAccountIsCreditCard,
                   selectedCategoryKind != .transfer
                {
                    refundSection
                }

                if store.supportsAdvancedCardRules, isPayingCreditCard {
                    statementPaymentSection
                }

                DatePicker("Data", selection: $occurredAt, displayedComponents: [.date])
                DatePicker("Hora", selection: $occurredAt, displayedComponents: [.hourAndMinute])

                LabeledContent("Notas") {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Opcional")
                                .foregroundStyle(.tertiary)
                                .padding(.top, GranaTheme.Spacing.xs)
                                .padding(.leading, GranaTheme.Spacing.xxs)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 80, maxHeight: 160)
                            .scrollContentBackground(.hidden)
                    }
                }

                if let saveError {
                    Text(saveError)
                        .foregroundStyle(.danger)
                        .font(GranaTheme.Typography.callout)
                }
            }
            .formStyle(.grouped)

            BottomActionBar {
                Button("Cancelar") { dismiss() }
                Button("Salvar", action: requestSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 680, idealWidth: 720, minHeight: 560)
        .alert("Prévia do recálculo", isPresented: $showsRetroactivePreview) {
            Button("Cancelar", role: .cancel) {}
            Button("Confirmar alteração") {
                Task { await save() }
            }
        } message: {
            Text(retroactivePreviewText)
        }
        .onAppear(perform: loadExisting)
        .onChange(of: store.accounts) { _, newAccounts in
            if existing == nil, accountId == nil, let first = newAccounts.first {
                accountId = first.id
            }
        }
        .onChange(of: store.categories) { _, _ in
            if existing == nil, categoryId == nil, let first = store.rootCategories.first {
                categoryId = first.id
            }
        }
    }

    // MARK: - Statement payment UI (Fase 4.7)

    private var statementPaymentSection: some View {
        Section {
            if automaticPaymentPreview.isEmpty {
                Text("Nenhuma dívida elegível nessa data.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(automaticPaymentPreview, id: \.statement.id) { item in
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
                "O valor inteiro será aplicado às dívidas elegíveis mais antigas. O salvamento será rejeitado se sobrar valor."
            )
        }
    }

    private var refundSection: some View {
        Section {
            Picker("Estorno de", selection: $refundOfTransactionId) {
                Text("Não é estorno").tag(UUID?.none)
                ForEach(refundablePurchases) { purchase in
                    Text(
                        "\(purchase.description) · \(store.remainingRefundableAmount(for: purchase).formatted(.currency(code: "BRL")))"
                    )
                    .tag(UUID?.some(purchase.id))
                }
            }
            .onChange(of: refundOfTransactionId) { _, purchaseId in
                guard let purchase = refundablePurchases.first(where: { $0.id == purchaseId }) else { return }
                categoryId = purchase.categoryId
                subcategoryId = purchase.subcategoryId
            }
        } header: {
            Text("Estorno")
        } footer: {
            Text("Estornos herdam conta e categoria da compra e pertencem ao ciclo da própria data.")
        }
    }

    /// "Fatura 05/2026 · Faltam R$ X,XX de R$ Y,YY". Mostra `closing_date`
    /// formatado (mês/ano da fatura) + saldo restante pra o usuário escolher
    /// a Fatura certa de bate-pronto.
    private func statementPickerLabel(_ statement: Statement) -> String {
        let monthYear = statement.closingDate.formatted(.dateTime.month().year())
        let remaining = store.remainingAmount(of: statement)
        let total = statement.totalAmount
        let remainingStr = remaining.formatted(.currency(code: "BRL"))
        let totalStr = total.formatted(.currency(code: "BRL"))
        return "Fatura \(monthYear) · Faltam \(remainingStr) de \(totalStr)"
    }

    // MARK: - Save

    private func requestSave() {
        if requiresRetroactivePreview {
            showsRetroactivePreview = true
        } else {
            Task { await save() }
        }
    }

    private var requiresRetroactivePreview: Bool {
        let isPast = occurredAt < Calendar.current.startOfDay(for: Date())
        guard isPast else { return false }
        return selectedAccountIsCreditCard || isPayingCreditCard
    }

    private var retroactivePreviewText: String {
        var effects: [String] = []
        if selectedAccountIsCreditCard {
            let closing = StatementWindow.resolve(
                closingDay: selectedCardDetails?.statementClosingDay ?? 1,
                paymentDueDay: selectedCardDetails?.paymentDueDay ?? 1,
                on: occurredAt
            ).closingDate
            effects
                .append(
                    "A fatura que fecha em \(closing.formatted(date: .abbreviated, time: .omitted)) será reconstruída."
                )
        }
        if isPayingCreditCard {
            effects
                .append(
                    "Pagamentos serão redistribuídos cronologicamente e a alteração será rejeitada se houver sobra."
                )
        }
        if let existing {
            let linkedRefunds = store.transactions.filter {
                $0.refundOfTransactionId == existing.id
            }.count
            if linkedRefunds > 0 {
                effects.append("\(linkedRefunds) estorno(s) vinculado(s) serão revalidados.")
            }
        }
        return effects.joined(separator: "\n")
    }

    private var canSave: Bool {
        guard !description.trimmingCharacters(in: .whitespaces).isEmpty,
              amountCents > 0,
              accountId != nil,
              categoryId != nil
        else { return false }
        // Transferência exige destino diferente da origem. `destinationAccountId`
        // nulo é aceito (transferência neutra, compat com legados); o que
        // bloqueia é destino == origem.
        if selectedCategoryKind == .transfer,
           let dest = destinationAccountId,
           dest == accountId
        {
            return false
        }
        if let purchaseId = refundOfTransactionId,
           let purchase = refundablePurchases.first(where: { $0.id == purchaseId }),
           Decimal(amountCents) / 100 > store.remainingRefundableAmount(for: purchase)
        {
            return false
        }
        return true
    }

    /// `kind` da categoria atualmente selecionada — usado pra decidir se mostra
    /// o picker de destino, decidir se persiste `destinationAccountId`, etc.
    /// `nil` se a categoria ainda não foi carregada no refresh assíncrono
    /// inicial ou nenhuma foi escolhida.
    private var selectedCategoryKind: CategoryKind? {
        guard let categoryId else { return nil }
        return store.categories.first { $0.id == categoryId }?.kind
    }

    /// Opções pro picker de destino: todas as contas menos a de origem
    /// (transferir pra si mesmo não faz sentido). Inclui arquivadas só se
    /// já era a contraparte de uma transferência existente — assim a edição
    /// não "perde" a conta arquivada do dropdown.
    private var destinationAccountOptions: [Account] {
        store.accounts.filter { account in
            guard account.id != accountId else { return false }
            if !store.supportsAdvancedCardRules,
               account.type == .creditCard,
               existing?.destinationAccountId != account.id
            {
                return false
            }
            if account.archived {
                return existing?.destinationAccountId == account.id
            }
            return true
        }
    }

    private var sourceAccountOptions: [Account] {
        store.accounts.filter { account in
            if !store.supportsAdvancedCardRules,
               account.type == .creditCard,
               existing?.accountId != account.id
            {
                return false
            }
            if account.archived {
                return existing?.accountId == account.id
            }
            return true
        }
    }

    private var isPayingCreditCard: Bool {
        guard selectedCategoryKind == .transfer,
              let dest = destinationAccountId,
              let account = store.account(for: dest)
        else { return false }
        return account.type == .creditCard
    }

    private var selectedAccountIsCreditCard: Bool {
        guard let accountId, let account = store.account(for: accountId) else { return false }
        return account.type == .creditCard
    }

    private var selectedCardDetails: CreditCardDetails? {
        guard let accountId else { return nil }
        return store.creditCards.first { $0.accountId == accountId }
    }

    private var refundablePurchases: [Transaction] {
        store.refundablePurchases(
            accountId: accountId,
            occurredAt: occurredAt,
            excluding: existing?.id
        )
    }

    private var automaticPaymentPreview: [(statement: Statement, amount: Decimal)] {
        guard let destinationAccountId else { return [] }
        return store.automaticPaymentPreview(
            accountId: destinationAccountId,
            amount: Decimal(amountCents) / 100,
            occurredAt: occurredAt
        )
    }

    private func loadExisting() {
        guard let existing else {
            // Defaults em "novo": primeira conta + primeira categoria raiz.
            // Pickers exigem uma seleção válida (sem opção "Selecione").
            if accountId == nil { accountId = store.accounts.first?.id }
            if categoryId == nil { categoryId = store.rootCategories.first?.id }
            return
        }
        description = existing.description
        amountCents = Int(truncatingIfNeeded: Converters.decimalToCents(existing.amount))
        occurredAt = existing.occurredAt
        accountId = existing.accountId
        categoryId = existing.categoryId
        subcategoryId = existing.subcategoryId
        destinationAccountId = existing.destinationAccountId
        refundOfTransactionId = existing.refundOfTransactionId
        notes = existing.notes ?? ""
    }

    private func save() async {
        guard let accountId, let categoryId else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesValue = trimmedNotes.isEmpty ? nil : trimmedNotes
        let amount = Decimal(amountCents) / 100

        // Só persiste destino quando a categoria é transferência. Trocar a
        // categoria pra outro kind sem reabrir o form não devia acontecer
        // (zeramos no onChange), mas o guard aqui é cinto + suspensório.
        let resolvedDestination: UUID? = (selectedCategoryKind == .transfer)
            ? destinationAccountId
            : nil

        do {
            if let existing {
                var updated = existing
                updated.accountId = accountId
                updated.categoryId = categoryId
                updated.subcategoryId = subcategoryId
                updated.amount = amount
                updated.occurredAt = occurredAt
                updated.description = description
                updated.notes = notesValue
                updated.destinationAccountId = resolvedDestination
                updated.refundOfTransactionId = refundOfTransactionId
                try await store.update(updated)
            } else {
                try await store.add(
                    accountId: accountId,
                    categoryId: categoryId,
                    subcategoryId: subcategoryId,
                    amount: amount,
                    occurredAt: occurredAt,
                    description: description,
                    notes: notesValue,
                    destinationAccountId: resolvedDestination,
                    refundOfTransactionId: refundOfTransactionId
                )
            }
            dismiss()
        } catch {
            saveError = error.localizedDescription
            NoticeCenter.shared.report(error, title: "Falha ao salvar transação")
        }
    }
}
