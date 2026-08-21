import Foundation
import Supabase

protocol CategoryCatalogRepositoryProtocol: Sendable {
    func load() async throws -> [Category]
}

struct CategoryCatalogRecord: Decodable, Sendable {
    let id: UUID
    let parentId: UUID?
    let name: String
    let kind: CategoryKind
    let slug: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case name
        case kind
        case slug
        case createdAt = "created_at"
    }
}

protocol CategoryCatalogRemoteStore: Sendable {
    func fetchCategories() async throws -> [CategoryCatalogRecord]
}

actor SupabaseCategoryCatalogRemoteStore: CategoryCatalogRemoteStore {
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

    func fetchCategories() async throws -> [CategoryCatalogRecord] {
        try await resolvedClient()
            .schema("api")
            .from("v1_category_catalog")
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

final class CategoryCatalogRepository: CategoryCatalogRepositoryProtocol, Sendable {
    private let remoteStore: any CategoryCatalogRemoteStore

    init(remoteStore: any CategoryCatalogRemoteStore) {
        self.remoteStore = remoteStore
    }

    func load() async throws -> [Category] {
        try await remoteStore.fetchCategories().map { record in
            Category(
                id: record.id,
                parentId: record.parentId,
                name: record.name,
                kind: record.kind,
                slug: record.slug,
                createdAt: record.createdAt
            )
        }
    }
}

struct StaticCategoryCatalogRepository: CategoryCatalogRepositoryProtocol {
    let categories: [Category]

    func load() async throws -> [Category] {
        categories
    }
}
