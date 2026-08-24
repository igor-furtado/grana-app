import Foundation
import SwiftUI

/// Catálogo read-only das instituições com suporte nativo no app — auto-detect
/// via código FEBRABAN no import OFX, ícone canônico e cor da marca. O
/// usuário não cria nem edita instituições; o que ele cria é **conta** (que
/// referencia uma instituição). Esta tela existe pra responder "que bancos
/// o GranaApp reconhece?" sem ter que abrir o form de conta.
struct SupportedInstitutionsView: View {
    @Environment(AppEnvironment.self) private var environment

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 16),
    ]
    @State private var store: InstitutionCatalogStore?

    var body: some View {
        Group {
            if let loadError {
                EmptyStateView(
                    "Não foi possível carregar",
                    icon: .warning,
                    description: loadError.localizedDescription
                )
            } else if isLoading, !hasLoaded {
                ProgressView()
            } else if institutions.isEmpty {
                EmptyStateView(
                    "Nenhuma instituição disponível",
                    icon: .sidebarInstitutions,
                    description: "O backend não devolveu instituições suportadas para a sessão atual."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(
                            "Catálogo global das instituições suportadas pelo produto. Tipos de conta e formatos de importação vêm do backend e definem o que a UI pode oferecer."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(institutions) { institution in
                                InstitutionCatalogCard(institution: institution)
                            }
                        }
                    }
                }
            }
        }
        .granaPagePadding()
        .navigationTitle("Bancos suportados")
        .navigationSubtitle("\(institutions.count) bancos disponíveis")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task { await load() }
    }

    private var institutions: [Institution] {
        store?.institutions ?? []
    }

    private var loadError: Error? {
        store?.loadError
    }

    private var isLoading: Bool {
        store?.isLoading ?? false
    }

    private var hasLoaded: Bool {
        store?.hasLoaded ?? false
    }

    private func load() async {
        if store == nil {
            store = InstitutionCatalogStore(container: environment.container)
        }
        await store?.load()
    }

    private func refresh() async {
        if store == nil {
            store = InstitutionCatalogStore(container: environment.container)
        }
        await store?.refresh()
    }
}

private struct InstitutionCatalogCard: View {
    let institution: Institution

    var body: some View {
        HStack(spacing: 14) {
            InstitutionIcon(kind: institution.kind, size: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text(institution.name)
                    .font(.body.weight(.semibold))
                Text("FEBRABAN \(institution.code)")
                    .font(GranaTheme.Typography.number(size: 12, weight: .regular))
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
            Spacer(minLength: 0)
        }
        .padding(14)
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
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(values.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
