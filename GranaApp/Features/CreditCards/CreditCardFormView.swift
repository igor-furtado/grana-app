import ComposableArchitecture
import SwiftUI

struct CreditCardFormView: View {
    @Bindable var store: StoreOf<CreditCardFormFeature>

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            Form {
                identitySection
                cardDetailsSection
                cardCycleSection

                if let saveError = store.saveError {
                    errorSection(message: saveError)
                }
            }
            .formStyle(.grouped)

            BottomActionBar {
                Button("Cancelar") {
                    store.send(.cancelButtonTapped)
                }
                Button(store.existingCard == nil ? "Cadastrar" : "Salvar") {
                    store.send(.saveButtonTapped)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canSave || store.isSaving)
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 520, idealWidth: 520, maxWidth: 520, minHeight: 480)
    }

    private var identitySection: some View {
        Section {
            Picker("Emissor", selection: $store.institutionId) {
                ForEach(store.availableInstitutions) { institution in
                    Label(institution.name, systemImage: institution.kind.systemImage)
                        .tag(UUID?.some(institution.id))
                }
            }
        } header: {
            Text("Identidade")
        }
    }

    private var cardDetailsSection: some View {
        Section {
            TextField("Últimos 4 dígitos", text: $store.cardLastFour, prompt: Text("Ex: 1234"))
            Toggle("Informar limite de crédito", isOn: $store.hasCreditLimit)
            if store.hasCreditLimit {
                LabeledContent("Limite") {
                    CurrencyField(cents: $store.creditLimitCents)
                }
            }
        } header: {
            Text("Detalhes do cartão")
        } footer: {
            if store.isCardLastFourPartial {
                Text("Informe os 4 dígitos completos.")
                    .foregroundStyle(.danger)
            } else {
                Text("Last4 distingue cartões do mesmo emissor e o limite é opcional.")
            }
        }
    }

    private var cardCycleSection: some View {
        Section {
            Picker("Dia de fechamento", selection: $store.statementClosingDay) {
                ForEach(1 ... 31, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            Picker("Dia de vencimento", selection: $store.paymentDueDay) {
                ForEach(1 ... 31, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
        } header: {
            Text("Ciclo da fatura")
        } footer: {
            Text(
                "Dias inexistentes usam o último dia do mês. Estes dias são o padrão para novas faturas; faturas já existentes mantêm datas próprias."
            )
        }
    }

    private func errorSection(message: String) -> some View {
        Section {
            Label {
                Text(message)
                    .foregroundStyle(.danger)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.danger)
            }
        }
    }
}
