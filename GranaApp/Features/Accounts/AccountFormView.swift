import AppUI
import ComposableArchitecture
import SwiftUI

/// Form de criação/edição de contas com saldo da vertical de Contas.
struct AccountFormView: View {
    @Bindable var store: StoreOf<AccountFormFeature>

    var body: some View {
        ZStack {
            GranaBackground()

            AppUI.Form.Shell {
                AppUI.Form.Header(
                    title: title,
                    subtitle: subtitle
                )

                Form {
                    identitySection
                    accountIdentitySection
                    balanceSection
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
                label: "Tipo",
                options: store.availableAccountTypes.map {
                    .init(id: $0, title: $0.displayName)
                },
                selection: $store.type,
                icon: AppUI.Icon.accountType.systemImage
            )
            AppUI.Selector(
                label: "Abrangência",
                options: AccountTerritorialScope.allCases.map {
                    .init(id: $0, title: $0.displayName)
                },
                selection: $store.territorialScope,
                icon: AppUI.Icon.territorialScope.systemImage
            )
            AppUI.Selector(
                label: "Instituição financeira",
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
                placeholder: "Ex: Reserva emergência",
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

    private var accountIdentitySection: some View {
        Section {
            if store.territorialScope == .brazilian {
                AppUI.TextField(
                    label: "Agência",
                    text: $store.branchId,
                    placeholder: "Ex: 0001-9",
                    textAlignment: .trailing
                )
            } else {
                AppUI.TextField(
                    label: "Banco",
                    text: $store.bankName,
                    placeholder: "Ex: Community Federal Savings Bank",
                    textAlignment: .trailing
                )
            }
            AppUI.TextField(
                label: accountNumberLabel,
                text: $store.accountNumber,
                placeholder: accountNumberPlaceholder,
                textAlignment: .trailing
            )
        } header: {
            sectionHeader("Identidade da conta")
        } footer: {
            sectionFooter(identityFooter)
        }
    }

    private var balanceSection: some View {
        Section {
            AppUI.CurrencyField(
                label: "Valor",
                cents: $store.balanceCents,
                currencyCode: store.currency,
                placeholder: store.currency == "BRL" ? "R$ 0,00" : "US$0.00"
            )
            AppUI.Toggle(label: "Saldo negativo", isOn: $store.balanceIsNegative)
        } header: {
            sectionHeader("Saldo inicial")
        } footer: {
            sectionFooter("Ative “Saldo negativo” se a conta estiver no vermelho.")
        }
    }

    private func errorSection(message: String) -> some View {
        Section {
            Label {
                Text(message)
                    .font(AppUI.Theme.Typography.callout)
                    .foregroundStyle(.danger)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.danger)
            }
        } header: {
            AppUI.Form.SectionHeader(title: "Erro ao salvar")
        }
    }

    private var primaryActionTitle: String {
        store.existingAccount == nil ? "Cadastrar" : "Salvar"
    }

    private var title: String {
        store.existingAccount == nil ? "Nova conta" : "Editar conta"
    }

    private var subtitle: String {
        "\(store.type.displayName) com identidade, abrangência e saldo inicial."
    }

    private var accountNumberLabel: String {
        store.territorialScope == .global ? "Account number" : "Número da conta"
    }

    private var accountNumberPlaceholder: String {
        store.territorialScope == .global ? "Ex: 8897077206" : "Ex: 310013887"
    }

    private var identityFooter: String {
        switch store.territorialScope {
        case .brazilian:
            return "Número da conta é obrigatório. Agência é opcional e ajuda a identificar importações OFX."
        case .global:
            return "Banco e account number são obrigatórios para identificar a conta global."
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        AppUI.Form.SectionHeader(title: title)
    }

    private func sectionFooter(_ text: String) -> some View {
        AppUI.Form.SectionFooter(text: text)
    }
}
