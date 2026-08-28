import ComposableArchitecture
import SwiftUI

/// Catálogo read-only das instituições com suporte nativo no app — auto-detect
/// via código FEBRABAN no import OFX, ícone canônico e cor da marca. O
/// usuário não cria nem edita instituições; o que ele cria é **conta** (que
/// referencia uma instituição). Esta tela existe pra responder "que bancos
/// o GranaApp reconhece?" sem ter que abrir o form de conta.
struct SupportedInstitutionsView: View {
    @Bindable var store: StoreOf<SupportedInstitutionsFeature>
    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 360), spacing: GranaTheme.Spacing.md),
    ]

    var body: some View {
        SupportedInstitutionsLoadedView(store: store, columns: columns)
            .navigationTitle("")
            .toolbar(.hidden, for: .windowToolbar)
    }
}

private struct SupportedInstitutionsLoadedView: View {
    @Bindable var store: StoreOf<SupportedInstitutionsFeature>
    let columns: [GridItem]

    var body: some View {
        VStack(spacing: GranaTheme.Spacing.sm) {
            FeatureScreenHeader(
                title: "Bancos suportados",
                subtitle: store.subtitle
            ) {
                Button {
                    store.send(.refresh)
                } label: {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                }
                .buttonStyle(GranaPrimaryButtonStyle())
                .disabled(store.isLoading)
            }

            Group {
                if let loadErrorMessage = store.loadErrorMessage {
                    EmptyStateView(
                        "Não foi possível carregar",
                        icon: .warning,
                        description: loadErrorMessage
                    )
                } else if store.isLoading, !store.hasLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.institutions.isEmpty {
                    EmptyStateView(
                        "Nenhuma instituição disponível",
                        icon: .sidebarInstitutions,
                        description: "O backend não devolveu instituições suportadas para a sessão atual."
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: GranaTheme.Spacing.md) {
                            Text(
                                """
                                Catálogo global das instituições suportadas pelo produto. Tipos de conta
                                e formatos de importação vêm do backend e definem o que a UI pode oferecer.
                                """
                            )
                            .font(GranaTheme.Typography.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                            LazyVGrid(columns: columns, spacing: GranaTheme.Spacing.md) {
                                ForEach(store.institutions) { institution in
                                    InstitutionCatalogCard(institution: institution)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            await store.send(.task).finish()
        }
    }
}

private struct InstitutionCatalogCard: View {
    let institution: Institution

    var body: some View {
        HStack(spacing: GranaTheme.Spacing.md) {
            InstitutionIcon(kind: institution.kind, size: 48)

            VStack(alignment: .leading, spacing: GranaTheme.Spacing.xs) {
                Text(institution.name)
                    .font(GranaTheme.Typography.bodyEmphasis)
                Text("FEBRABAN \(institution.code)")
                    .font(GranaTheme.Typography.code)
                    .foregroundStyle(.secondary)

                capabilityRow(
                    title: "Contas",
                    values: institution.capabilities.supportedAccountTypes
                        .sorted { $0.displayName < $1.displayName }
                        .map(\.displayName)
                )
                capabilityRow(
                    title: "Importação",
                    values: institution.capabilities.supportedImportFormats
                        .sorted { $0.displayName < $1.displayName }
                        .map(\.displayName)
                )
            }
            Spacer(minLength: GranaTheme.Spacing.none)
        }
        .padding(GranaTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(institution.kind.brandColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func capabilityRow(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: GranaTheme.Spacing.xxs) {
            Text(title)
                .font(GranaTheme.Typography.caption2Emphasis)
                .foregroundStyle(.secondary)
            Text(values.joined(separator: " · "))
                .font(GranaTheme.Typography.caption1)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
