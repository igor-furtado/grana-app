import ComposableArchitecture
import SwiftUI

/// Form de criação/edição de conta corrente da vertical de Contas.
struct AccountFormView: View {
    @Bindable var store: StoreOf<AccountFormFeature>

    var body: some View {
        ZStack {
            GranaBackground()

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
                header

                Form {
                    identitySection
                    bankIdentitySection
                    balanceSection
                    if let saveError = store.saveError {
                        errorSection(message: saveError)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

                BottomActionBar {
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
            .padding(.vertical, GranaTheme.Spacing.lg)
            .granaSurface(.subtle, cornerRadius: GranaTheme.Radius.card)
            .padding(GranaTheme.Spacing.sm)
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 560, idealWidth: 560, maxWidth: 560, minHeight: 560)
        .onExitCommand {
            store.send(.cancelButtonTapped)
        }
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
            sectionHeader("Identidade")
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
            sectionHeader("Identidade bancária")
        } footer: {
            sectionFooter(
                "Obrigatórios. Distinguem contas do mesmo banco e ajudam a identificar a conta em importações OFX."
            )
        }
    }

    private var balanceSection: some View {
        Section {
            AppUI.CurrencyField(
                label: "Valor",
                cents: $store.balanceCents
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
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(.danger)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.danger)
            }
        } header: {
            sectionHeader("Erro ao salvar")
        }
    }

    private var primaryActionTitle: String {
        store.existingAccount == nil ? "Cadastrar" : "Salvar"
    }

    private var title: String {
        store.existingAccount == nil ? "Nova conta" : "Editar conta"
    }

    private var subtitle: String {
        "Conta corrente com dados bancários e saldo inicial."
    }

    private var header: some View {
        HStack(alignment: .top, spacing: GranaTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                Text(title)
                    .font(GranaTheme.Typography.title3)
                    .foregroundStyle(GranaTheme.Palette.ink)

                Text(subtitle)
                    .font(GranaTheme.Typography.subheadline)
                    .foregroundStyle(GranaTheme.Palette.muted)
            }

            Spacer(minLength: GranaTheme.Spacing.none)
        }
        .padding(.horizontal, GranaTheme.Spacing.lg)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(GranaTheme.Typography.subheadlineEmphasis)
            .foregroundStyle(GranaTheme.Palette.ink)
            .textCase(nil)
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(GranaTheme.Typography.footnote)
            .foregroundStyle(GranaTheme.Palette.muted)
            .textCase(nil)
    }
}
