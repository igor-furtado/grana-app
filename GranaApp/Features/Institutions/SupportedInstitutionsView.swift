import AppUI
import ComposableArchitecture
import SwiftUI

/// Catálogo read-only das instituições com suporte nativo no app — auto-detect
/// via código FEBRABAN no import OFX, ícone canônico e cor da marca. O
/// usuário não cria nem edita instituições; o que ele cria é **conta** (que
/// referencia uma instituição). Esta tela existe pra responder "que instituições
/// o GranaApp reconhece?" sem ter que abrir o form de conta.
struct SupportedInstitutionsView: View {
    @Bindable var store: StoreOf<SupportedInstitutionsFeature>

    var body: some View {
        SupportedInstitutionsLoadedView(store: store)
    }
}

private struct SupportedInstitutionsLoadedView: View {
    @Bindable var store: StoreOf<SupportedInstitutionsFeature>
    @State private var sortOrder = [
        KeyPathComparator(\SupportedInstitutionTableRow.name),
    ]

    var body: some View {
        VStack(spacing: AppUI.Theme.Spacing.sm) {
            AppUI.Layout.ScreenHeader(
                title: "Instituições financeiras",
                subtitle: store.subtitle
            )

            Group {
                if store.isLoading {
                    SupportedInstitutionsSkeletonView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadErrorMessage = store.loadErrorMessage {
                    EmptyStateView(
                        "Não foi possível carregar",
                        icon: .warning,
                        description: loadErrorMessage
                    )
                } else if store.institutions.isEmpty {
                    EmptyStateView(
                        "Nenhuma instituição disponível",
                        icon: .sidebarInstitutions,
                        description: "O backend não devolveu instituições suportadas para a sessão atual."
                    )
                } else {
                    institutionsTable
                }
            }
        }
        .task {
            await store.send(.task).finish()
        }
    }

    private var institutionsTable: some View {
        AppUI.Table(tableRows, sortOrder: $sortOrder) {
            TableColumn("Instituição", value: \.name) { row in
                HStack(spacing: AppUI.Theme.Spacing.sm) {
                    InstitutionIcon(kind: row.kind, size: 24)
                    Text(row.name)
                        .font(AppUI.Theme.Typography.subheadlineEmphasis)
                        .foregroundStyle(AppUI.Theme.Palette.ink)
                        .lineLimit(1)
                }
            }
            .width(min: 240, ideal: 280, max: 340)

            TableColumn("FEBRABAN", value: \.code) { row in
                Text(row.code)
                    .font(AppUI.Theme.Typography.code)
                    .foregroundStyle(AppUI.Theme.Palette.muted)
            }
            .width(min: 90, ideal: 110, max: 120)

            TableColumn("Tipos", value: \.accountTypesSortLabel) { row in
                CapabilityBadgeGroup(values: row.accountTypes)
            }
            .width(min: 220, ideal: 280, max: 360)

            TableColumn("Importação", value: \.importFormatsSortLabel) { row in
                CapabilityBadgeGroup(values: row.importFormats)
            }
        }
    }

    private var tableRows: [SupportedInstitutionTableRow] {
        store.institutions.map(SupportedInstitutionTableRow.init(institution:))
    }
}

private struct SupportedInstitutionTableRow: Identifiable {
    let id: Institution.ID
    let name: String
    let code: String
    let kind: InstitutionKind
    let accountTypes: [String]
    let importFormats: [String]

    var accountTypesSortLabel: String {
        accountTypes.joined(separator: " ")
    }

    var importFormatsSortLabel: String {
        importFormats.joined(separator: " ")
    }

    init(institution: Institution) {
        self.id = institution.id
        self.name = institution.name
        self.code = institution.code
        self.kind = institution.kind
        self.accountTypes = institution.capabilities.supportedAccountTypes
            .sorted { $0.displayName < $1.displayName }
            .map(\.displayName)
        self.importFormats = institution.capabilities.supportedImportFormats
            .sorted { $0.displayName < $1.displayName }
            .map(\.displayName)
    }
}

private struct CapabilityBadgeGroup: View {
    let values: [String]

    var body: some View {
        HStack(spacing: AppUI.Theme.Spacing.xs) {
            ForEach(values, id: \.self) { value in
                CapabilityBadge(value)
            }
        }
        .lineLimit(1)
    }
}

private struct CapabilityBadge: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(AppUI.Theme.Typography.caption1Emphasis)
            .foregroundStyle(AppUI.Theme.Palette.tealDeep)
            .padding(.horizontal, AppUI.Theme.Spacing.xs)
            .padding(.vertical, AppUI.Theme.Spacing.xxs)
            .background(AppUI.Theme.Palette.teal.opacity(0.10), in: Capsule())
    }
}
