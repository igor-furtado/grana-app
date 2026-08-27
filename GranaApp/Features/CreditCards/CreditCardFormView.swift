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

struct CreditCardArchiveView: View {
    @Bindable var store: StoreOf<CreditCardArchiveFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
            Text(store.title)
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)

            Text(store.message)
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)

            if let saveError = store.saveError {
                Text(saveError)
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(.danger)
            }

            BottomActionBar {
                Button("Cancelar") {
                    store.send(.cancelButtonTapped)
                }
                Button(store.confirmTitle) {
                    store.send(.confirmButtonTapped)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSaving)
            }
        }
        .padding(GranaTheme.Spacing.xl)
        .frame(minWidth: 460, idealWidth: 460)
    }
}

struct CreditCardDeleteView: View {
    @Bindable var store: StoreOf<CreditCardDeleteFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.lg) {
            Text("Apagar cartão")
                .font(GranaTheme.Typography.title3)
                .foregroundStyle(GranaTheme.Palette.ink)

            Text("O cartão só será apagado se não houver transações, faturas ou lotes de importação vinculados.")
                .font(GranaTheme.Typography.callout)
                .foregroundStyle(GranaTheme.Palette.muted)

            if let saveError = store.saveError {
                Text(saveError)
                    .font(GranaTheme.Typography.callout)
                    .foregroundStyle(.danger)
            }

            BottomActionBar {
                Button("Cancelar") {
                    store.send(.cancelButtonTapped)
                }
                Button("Apagar") {
                    store.send(.confirmButtonTapped)
                }
                .buttonStyle(.borderedProminent)
                .tint(.danger)
                .disabled(store.isSaving)
            }
        }
        .padding(GranaTheme.Spacing.xl)
        .frame(minWidth: 460, idealWidth: 460)
    }
}
