import Foundation
import Supabase

protocol InstitutionCatalogRepositoryProtocol: Sendable {
    func load() async throws -> [Institution]
}

struct InstitutionCatalogRecord: Decodable, Sendable {
    let id: UUID
    let code: String
    let name: String
    let kind: String
    let supportedAccountTypes: [AccountType]
    let supportedImportFormats: [InstitutionImportFormat]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case kind
        case supportedAccountTypes = "supported_account_types"
        case supportedImportFormats = "supported_import_formats"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

protocol InstitutionCatalogRemoteStore: Sendable {
    func fetchInstitutions() async throws -> [InstitutionCatalogRecord]
}

actor SupabaseInstitutionCatalogRemoteStore: InstitutionCatalogRemoteStore {
    private let authClient: any AuthClientProtocol
    private let supabaseURL: String
    private let supabaseAnonKey: String
    private var client: SupabaseClient?

    init(
        authClient: any AuthClientProtocol,
        supabaseURL: String? = nil,
        supabaseAnonKey: String? = nil
    ) {
        self.authClient = authClient
        self.supabaseURL = supabaseURL ?? Config.supabaseURL
        self.supabaseAnonKey = supabaseAnonKey ?? Config.supabaseAnonKey
    }

    func fetchInstitutions() async throws -> [InstitutionCatalogRecord] {
        try await resolvedClient()
            .schema("api")
            .from("v1_supported_institution_catalog")
            .select()
            .order("name", ascending: true)
            .execute()
            .value
    }

    private func resolvedClient() throws -> SupabaseClient {
        if let client {
            return client
        }
        let client = try SupabaseAuthenticatedClientFactory.makeClient(
            authClient: authClient,
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey
        )
        self.client = client
        return client
    }
}

final class InstitutionCatalogRepository: InstitutionCatalogRepositoryProtocol, Sendable {
    private let remoteStore: any InstitutionCatalogRemoteStore

    init(remoteStore: any InstitutionCatalogRemoteStore) {
        self.remoteStore = remoteStore
    }

    func load() async throws -> [Institution] {
        try await remoteStore.fetchInstitutions().map { record in
            Institution(
                id: record.id,
                code: record.code,
                name: record.name,
                kind: InstitutionKind(rawValue: record.kind) ?? .other,
                capabilities: InstitutionCapabilities(
                    supportedAccountTypes: Set(record.supportedAccountTypes),
                    supportedImportFormats: Set(record.supportedImportFormats)
                ),
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }
    }
}

struct StaticInstitutionCatalogRepository: InstitutionCatalogRepositoryProtocol {
    let institutions: [Institution]

    func load() async throws -> [Institution] {
        institutions
    }
}

struct AuthRequiredInstitutionCatalogRepository: InstitutionCatalogRepositoryProtocol {
    func load() async throws -> [Institution] {
        throw CatalogRepositoryError.authenticationRequired
    }
}
