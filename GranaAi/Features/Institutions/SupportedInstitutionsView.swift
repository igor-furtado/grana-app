import Foundation
import SwiftUI

/// Catálogo read-only das instituições com suporte nativo no app — auto-detect
/// via código FEBRABAN no import OFX, ícone canônico e cor da marca. O
/// usuário não cria nem edita instituições; o que ele cria é **conta** (que
/// referencia uma instituição). Esta tela existe pra responder "que bancos
/// o Grana AI reconhece?" sem ter que abrir o form de conta.
struct SupportedInstitutionsView: View {
    @Environment(AppEnvironment.self) private var environment

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 16),
    ]
    @State private var institutions: [Institution] = []
    @State private var loadError: Error?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let loadError {
                EmptyStateView(
                    "Não foi possível carregar",
                    icon: .warning,
                    description: loadError.localizedDescription
                )
            } else if institutions.isEmpty, isLoading {
                ProgressView()
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
        .padding(20)
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

    private func load() async {
        guard institutions.isEmpty else { return }
        await refresh()
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            loadError = nil
            institutions = try await environment.container.institutionCatalog.load()
        } catch {
            loadError = error
            NoticeCenter.shared.report(error)
        }
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

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
