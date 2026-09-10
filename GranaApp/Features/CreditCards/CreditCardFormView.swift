import AppUI
import ComposableArchitecture
import SwiftUI

struct CreditCardFormView: View {
    @Bindable var store: StoreOf<CreditCardFormFeature>

    var body: some View {
        ZStack {
            GranaBackground()

            AppUI.Form.Shell {
                header

                Form {
                    identitySection
                    cardDetailsSection
                    cardCycleSection

                    if let saveError = store.saveError {
                        errorSection(message: saveError)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

                AppUI.Form.Actions {
                    Button("Cancelar") {
                        store.send(.cancelButtonTapped)
                    }
                    .buttonStyle(GranaSecondaryButtonStyle())

                    Button(primaryActionTitle) {
                        store.send(.saveButtonTapped)
                    }
                    .buttonStyle(GranaPrimaryButtonStyle())
                    .disabled(!store.canSave || store.isSaving)
                }
            }
        }
        .frame(minWidth: 560, idealWidth: 560, maxWidth: 560, minHeight: 560)
        .onExitCommand {
            store.send(.cancelButtonTapped)
        }
    }

    private var identitySection: some View {
        Section {
            AppUI.Selector(
                label: "Abrangência",
                options: AccountTerritorialScope.allCases.map {
                    .init(id: $0, title: $0.displayName)
                },
                selection: $store.territorialScope,
                icon: AppUI.Icon.territorialScope.systemImage
            )
            AppUI.Selector(
                label: "Emissor",
                placeholder: "Selecione…",
                options: store.availableInstitutions.map {
                    .init(id: $0.id, title: $0.name)
                },
                selection: $store.institutionId,
                icon: "building.columns"
            )
            AppUI.TextField(
                label: "Apelido",
                text: $store.nickname,
                placeholder: "Ex: Cartão principal",
                textAlignment: .trailing
            )
            if store.territorialScope == .global {
                AppUI.Selector(
                    label: "Moeda",
                    options: store.availableCurrencies.map {
                        .init(id: $0, title: $0)
                    },
                    selection: $store.currency,
                    icon: AppUI.Icon.currency.systemImage
                )
            }
        } header: {
            AppUI.Form.SectionHeader(title: "Identidade")
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
                AppUI.CurrencyField(
                    label: "Limite",
                    cents: $store.creditLimitCents,
                    currencyCode: store.currency,
                    placeholder: store.currency == "BRL" ? "R$ 0,00" : "US$0.00"
                )
            }
        } header: {
            AppUI.Form.SectionHeader(title: "Detalhes do cartão")
        } footer: {
            if store.isCardLastFourPartial {
                AppUI.Form.SectionFooter(text: "Informe os 4 dígitos completos.")
                    .foregroundStyle(.danger)
            } else {
                AppUI.Form.SectionFooter(text: "Last4 distingue cartões do mesmo emissor e o limite é opcional.")
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
            AppUI.Form.SectionHeader(title: "Ciclo da fatura")
        } footer: {
            AppUI.Form.SectionFooter(
                text:
                "Dias inexistentes usam o último dia do mês. Estes dias são o padrão para novas faturas; faturas já existentes mantêm datas próprias."
            )
        }
    }

    private func errorSection(message: String) -> some View {
        Section {
            AppUI.Form.ErrorMessage(message: message)
        } header: {
            AppUI.Form.SectionHeader(title: "Erro ao salvar")
        }
    }

    private var primaryActionTitle: String {
        store.existingCard == nil ? "Cadastrar" : "Salvar"
    }

    private var header: some View {
        AppUI.Form.Header(
            title: store.existingCard == nil ? "Novo cartão" : "Editar cartão",
            subtitle: "Cartão de crédito com emissor, abrangência, limite e ciclo padrão da fatura."
        )
    }
}
