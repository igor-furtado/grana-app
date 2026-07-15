import Foundation
import OSLog
import PowerSync
import Supabase

final class SupabaseConnector: PowerSyncBackendConnectorProtocol {
    private enum SyncedTable {
        static let names: Set<String> = [
            "accounts",
            "bank_accounts",
            "credit_cards",
            "credit_card_cycle_configs",
            "statements",
            "import_batches",
            "transactions",
            "statement_payments",
            "statement_credit_applications",
            "categorization_cache",
            "categorization_corrections",
        ]
    }

    private let authClient: any AuthClientProtocol
    private let powerSyncURL: String
    private let remoteStore: any SyncRemoteStore

    init(
        authClient: any AuthClientProtocol,
        powerSyncURL: String = Config.powerSyncURL,
        supabaseURL: String = Config.supabaseURL,
        supabaseAnonKey: String = Config.supabaseAnonKey,
        remoteStore: (any SyncRemoteStore)? = nil
    ) {
        self.authClient = authClient
        self.powerSyncURL = powerSyncURL
        self.remoteStore = remoteStore ?? SupabaseRemoteStore(
            authClient: authClient,
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey
        )
    }

    func fetchCredentials() async throws -> PowerSyncCredentials? {
        guard let session = try await authClient.validSession() else {
            return nil
        }
        return PowerSyncCredentials(
            endpoint: try AppConfigurationValidator.powerSyncURL(powerSyncURL),
            token: session.accessToken
        )
    }

    func uploadData(database: PowerSyncDatabaseProtocol) async throws {
        guard let transaction = try await database.getNextCrudTransaction() else { return }

        var lastEntry: (any CrudEntry)?
        do {
            let userID = try await currentUserID()
            for entry in transaction.crud {
                lastEntry = entry

                guard SyncedTable.names.contains(entry.table) else { continue }

                switch entry.op {
                case .put:
                    var row = entry.opData ?? [:]
                    row["id"] = entry.id
                    row["user_id"] = userID
                    try await remoteStore.upsert(table: entry.table, row: row)
                case .patch:
                    guard let values = entry.opData, !values.isEmpty else { continue }
                    try await remoteStore.update(
                        table: entry.table,
                        id: entry.id,
                        userID: userID,
                        values: values
                    )
                case .delete:
                    try await remoteStore.delete(
                        table: entry.table,
                        id: entry.id,
                        userID: userID
                    )
                }
            }

            try await transaction.complete()
        } catch {
            if let errorCode = PostgresFatalCodes.extractErrorCode(from: error),
               PostgresFatalCodes.isFatalError(errorCode)
            {
                log.sync.error(
                    "Erro fatal ao enviar CRUD local; descartando transação pendente. table=\(lastEntry?.table ?? "unknown", privacy: .public) op=\(lastEntry?.op.rawValue ?? "unknown", privacy: .public)"
                )
                try await transaction.complete()
                return
            }

            log.sync.error(
                "Erro transitório ao enviar CRUD local; transação seguirá para retry. table=\(lastEntry?.table ?? "unknown", privacy: .public) op=\(lastEntry?.op.rawValue ?? "unknown", privacy: .public)"
            )
            throw error
        }
    }

    private func currentUserID() async throws -> String {
        guard let session = try await authClient.validSession() else {
            throw AIError.authenticationRequired
        }
        return session.userID.uuidString.lowercased()
    }
}

protocol SyncRemoteStore: Sendable {
    func upsert(table: String, row: [String: String?]) async throws
    func update(
        table: String,
        id: String,
        userID: String,
        values: [String: String?]
    ) async throws
    func delete(table: String, id: String, userID: String) async throws
}

private actor SupabaseRemoteStore: SyncRemoteStore {
    private let authClient: any AuthClientProtocol
    private let supabaseURL: String
    private let supabaseAnonKey: String
    private var client: SupabaseClient?

    init(
        authClient: any AuthClientProtocol,
        supabaseURL: String,
        supabaseAnonKey: String
    ) {
        self.authClient = authClient
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
    }

    func upsert(table: String, row: [String: String?]) async throws {
        let client = try resolvedClient()
        try await client
            .from(table)
            .upsert(row, onConflict: "id", returning: .minimal)
            .execute()
    }

    func update(
        table: String,
        id: String,
        userID: String,
        values: [String: String?]
    ) async throws {
        let client = try resolvedClient()
        try await client
            .from(table)
            .update(values, returning: .minimal)
            .eq("id", value: id)
            .eq("user_id", value: userID)
            .execute()
    }

    func delete(table: String, id: String, userID: String) async throws {
        let client = try resolvedClient()
        try await client
            .from(table)
            .delete(returning: .minimal)
            .eq("id", value: id)
            .eq("user_id", value: userID)
            .execute()
    }

    private func resolvedClient() throws -> SupabaseClient {
        if let client {
            return client
        }

        let validatedURL = try AppConfigurationValidator.supabaseURL(supabaseURL)
        let validatedAnonKey = try AppConfigurationValidator.supabaseAnonKey(supabaseAnonKey)
        let client = SupabaseClient(
            supabaseURL: validatedURL,
            supabaseKey: validatedAnonKey,
            options: SupabaseClientOptions(auth: .init(
                accessToken: { [authClient] in
                    try await authClient.validSession()?.accessToken
                }
            ))
        )
        self.client = client
        return client
    }
}

private enum PostgresFatalCodes {
    static let fatalResponseCodes: [String] = [
        "22...",
        "23...",
        "42501",
    ]

    static func isFatalError(_ code: String) -> Bool {
        fatalResponseCodes.contains { pattern in
            code.range(of: pattern, options: [.regularExpression]) != nil
        }
    }

    static func extractErrorCode(from error: any Error) -> String? {
        if let postgrestError = error as? PostgrestError {
            return postgrestError.code
        }
        let errorString = String(describing: error)
        guard let range = errorString.range(
            of: "code: Optional\\(\"([^\"]+)\"\\)",
            options: [.regularExpression]
        ),
        let codeRange = errorString[range].range(
            of: "\"([^\"]+)\"",
            options: [.regularExpression]
        ) else {
            return nil
        }
        return String(errorString[codeRange].dropFirst().dropLast())
    }
}
