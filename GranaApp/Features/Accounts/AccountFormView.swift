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
            Picker("Banco", selection: $store.institutionId) {
                ForEach(store.availableInstitutions) { institution in
                    Label(institution.name, systemImage: institution.kind.systemImage)
                        .tag(UUID?.some(institution.id))
                }
            }
        } header: {
            Text("Identidade")
        }
    }

    private var bankIdentitySection: some View {
        Section {
            TextField("Agência", text: $store.branchId, prompt: Text("Ex: 0001-9"))
            TextField("Número da conta", text: $store.accountNumber, prompt: Text("Ex: 310013887"))
        } header: {
            Text("Identidade bancária")
        } footer: {
            Text("Obrigatórios. Distinguem contas do mesmo banco e habilitam o auto-detect da conta no import de OFX.")
        }
    }

    private var balanceSection: some View {
        Section {
            LabeledContent("Valor") {
                CurrencyField(cents: $store.balanceCents)
            }
            Toggle("Saldo negativo", isOn: $store.balanceIsNegative)
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
