import ComposableArchitecture
import SwiftUI

/// Form de criação/edição de conta corrente da vertical de Contas.
struct AccountFormView: View {
    @Bindable var store: StoreOf<AccountFormFeature>

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.none) {
            Form {
                identitySection
                bankIdentitySection
                balanceSection
                if let saveError = store.saveError {
                    errorSection(message: saveError)
                }
            }
            .formStyle(.grouped)

            VStack(spacing: GranaTheme.Spacing.none) {
                Button("Cancelar") {
                    store.send(.cancelButtonTapped)
                }
                Button(store.existingAccount == nil ? "Cadastrar" : "Salvar") {
                    store.send(.saveButtonTapped)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canSave || store.isSaving)
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 520, idealWidth: 520, maxWidth: 520, minHeight: 520)
    }

    private var identitySection: some View {
        Section {
            AppUI.Selector(
                label: "Banco",
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

    private var bankIdentitySection: some View {
        Section {
            AppUI.TextField(
                label: "Agência",
                text: $store.branchId,
                placeholder: "Ex: 0001-9",
                textAlignment: .trailing
            )
            AppUI.TextField(
                label: "Número da conta",
                text: $store.accountNumber,
                placeholder: "Ex: 310013887",
                textAlignment: .trailing
            )
        } header: {
            Text("Identidade bancária")
        } footer: {
            Text("Obrigatórios. Distinguem contas do mesmo banco e habilitam o auto-detect da conta no import de OFX.")
        }
    }

    private var balanceSection: some View {
        Section {
            AppUI.CurrencyField(
                label: "Valor",
                cents: $store.balanceCents)
            AppUI.Toggle(label: "Saldo negativo", isOn: $store.balanceIsNegative)
        } header: {
            Text("Saldo inicial")
        } footer: {
            Text(
                "Quanto você já tem nessa conta hoje. Ative “Saldo negativo” se a conta está no vermelho (cheque especial)."
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
