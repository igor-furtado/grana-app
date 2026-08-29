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
            AppUI.Selector(
                label: "Emissor",
                placeholder: "Selecione…",
                options: store.availableInstitutions.map {
                    .init(id: $0.id, title: $0.name)
                },
                selection: $store.institutionId,
                icon: "building.columns"
            )
        } header: {
            Text("Identidade")
        }
    }

    private var cardDetailsSection: some View {
        Section {
            AppUI.TextField(
                label: "Últimos 4 dígitos",
                text: $store.cardLastFour,
                placeholder: "Ex: 1234",
                textAlignment: .trailing
            )
            AppUI.Toggle(label: "Informar limite de crédito", isOn: $store.hasCreditLimit)
            if store.hasCreditLimit {
                AppUI.CurrencyField(label: "Limite", cents: $store.creditLimitCents)
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
            AppUI.Selector(
                label: "Dia de fechamento",
                options: (1 ... 31).map { .init(id: $0, title: "\($0)") },
                selection: $store.statementClosingDay,
                icon: "calendar"
            )
            AppUI.Selector(
                label: "Dia de vencimento",
                options: (1 ... 31).map { .init(id: $0, title: "\($0)") },
                selection: $store.paymentDueDay,
                icon: "calendar"
            )
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
