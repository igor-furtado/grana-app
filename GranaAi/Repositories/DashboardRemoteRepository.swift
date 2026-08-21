import Foundation
import Supabase

nonisolated struct DashboardRemoteSnapshot: Sendable {
    var totalBalance: Decimal
    var periodExpenses: Decimal
    var periodIncome: Decimal
    var expensesByCategory: [CategoryTotal]
    var weekdayExpenses: [WeekdayTotal]
    var monthlyByKind: [MonthlyKindTotal]

    static let empty = DashboardRemoteSnapshot(
        totalBalance: 0,
        periodExpenses: 0,
        periodIncome: 0,
        expensesByCategory: [],
        weekdayExpenses: [],
        monthlyByKind: []
    )
}

protocol DashboardRemoteRepositoryProtocol: Sendable {
    func load(
        filter: PeriodFilter,
        timeZone: TimeZone,
        today: Date,
        timezoneOverride: String?
    ) async throws -> DashboardRemoteSnapshot
}

nonisolated enum DashboardRemoteRepositoryError: UserFacingError, Equatable {
    case authenticationRequired

    var errorTitle: String {
        "Falha ao carregar dashboard"
    }

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "É preciso entrar com sua conta para carregar os agregados do dashboard."
        }
    }
}

nonisolated struct DashboardSummaryRow: Decodable, Sendable {
    let totalBalanceCents: Int64
    let periodExpenseCents: Int64
    let periodIncomeCents: Int64

    enum CodingKeys: String, CodingKey {
        case totalBalanceCents = "total_balance_cents"
        case periodExpenseCents = "period_expense_cents"
        case periodIncomeCents = "period_income_cents"
    }
}

nonisolated struct DashboardProfileTimezoneRow: Decodable, Sendable {
    let timezone: String
}

nonisolated struct DashboardCategoryTotalRow: Decodable, Sendable {
    let categoryId: UUID
    let categoryName: String
    let categorySlug: String?
    let totalCents: Int64

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case categorySlug = "category_slug"
        case totalCents = "total_cents"
    }
}

nonisolated struct DashboardWeekdayTotalRow: Decodable, Sendable {
    let weekday: Int
    let totalCents: Int64
    let count: Int

    enum CodingKeys: String, CodingKey {
        case weekday
        case totalCents = "total_cents"
        case count
    }
}

nonisolated struct DashboardMonthlyKindTotalRow: Decodable, Sendable {
    let monthStart: Date
    let incomeCents: Int64
    let expenseCents: Int64

    enum CodingKeys: String, CodingKey {
        case monthStart = "month_start"
        case incomeCents = "income_cents"
        case expenseCents = "expense_cents"
    }
}

nonisolated struct DashboardAggregateRequest: Encodable, Hashable, Sendable {
    let pFromDate: String
    let pToDate: String
    let pTimezoneOverride: String?

    init(
        fromDate: String,
        toDate: String,
        timezoneOverride: String?
    ) {
        pFromDate = fromDate
        pToDate = toDate
        pTimezoneOverride = timezoneOverride
    }

    enum CodingKeys: String, CodingKey {
        case pFromDate = "p_from_date"
        case pToDate = "p_to_date"
        case pTimezoneOverride = "p_timezone_override"
    }
}

protocol DashboardRemoteStore: Sendable {
    func fetchProfileTimezone() async throws -> [DashboardProfileTimezoneRow]
    func fetchSummary(request: DashboardAggregateRequest) async throws -> [DashboardSummaryRow]
    func fetchExpenseCategoryTotals(request: DashboardAggregateRequest) async throws -> [DashboardCategoryTotalRow]
    func fetchExpenseWeekdayTotals(request: DashboardAggregateRequest) async throws -> [DashboardWeekdayTotalRow]
    func fetchMonthlyKindTotals(request: DashboardAggregateRequest) async throws -> [DashboardMonthlyKindTotalRow]
}

actor SupabaseDashboardRemoteStore: DashboardRemoteStore {
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

    func fetchProfileTimezone() async throws -> [DashboardProfileTimezoneRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_get_profile_timezone")
            .execute()
            .value
    }

    func fetchSummary(request: DashboardAggregateRequest) async throws -> [DashboardSummaryRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_get_dashboard_summary", params: request)
            .execute()
            .value
    }

    func fetchExpenseCategoryTotals(request: DashboardAggregateRequest) async throws -> [DashboardCategoryTotalRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_list_dashboard_expense_category_totals", params: request)
            .execute()
            .value
    }

    func fetchExpenseWeekdayTotals(request: DashboardAggregateRequest) async throws -> [DashboardWeekdayTotalRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_list_dashboard_expense_weekday_totals", params: request)
            .execute()
            .value
    }

    func fetchMonthlyKindTotals(request: DashboardAggregateRequest) async throws -> [DashboardMonthlyKindTotalRow] {
        try await resolvedClient()
            .schema("api")
            .rpc("v1_list_dashboard_monthly_kind_totals", params: request)
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

final class DashboardRemoteRepository: DashboardRemoteRepositoryProtocol, Sendable {
    private struct ResolvedDashboardTimeZone {
        let calendarTimeZone: TimeZone
        let requestOverride: String?
    }

    private let remoteStore: any DashboardRemoteStore

    init(remoteStore: any DashboardRemoteStore) {
        self.remoteStore = remoteStore
    }

    func load(
        filter: PeriodFilter,
        timeZone: TimeZone,
        today: Date,
        timezoneOverride: String?
    ) async throws -> DashboardRemoteSnapshot {
        let resolvedTimeZone = try await resolveTimeZone(
            fallbackTimeZone: timeZone,
            explicitOverride: timezoneOverride
        )
        let request = Self.makeRequest(
            filter: filter,
            timeZone: resolvedTimeZone.calendarTimeZone,
            today: today,
            timezoneOverride: resolvedTimeZone.requestOverride
        )

        async let summaryRows = remoteStore.fetchSummary(request: request)
        async let categoryRows = remoteStore.fetchExpenseCategoryTotals(request: request)

        switch filter.scope {
        case .singleMonth:
            async let weekdayRows = remoteStore.fetchExpenseWeekdayTotals(request: request)
            let (summary, categories, weekdays) = try await (
                summaryRows,
                categoryRows,
                weekdayRows
            )
            let mappedSummary = Self.mapSummary(summary)
            return DashboardRemoteSnapshot(
                totalBalance: mappedSummary.totalBalance,
                periodExpenses: mappedSummary.periodExpenses,
                periodIncome: mappedSummary.periodIncome,
                expensesByCategory: categories.map(Self.mapCategoryTotal),
                weekdayExpenses: weekdays.map(Self.mapWeekdayTotal),
                monthlyByKind: []
            )

        case .multiMonth:
            async let monthlyRows = remoteStore.fetchMonthlyKindTotals(request: request)
            let (summary, categories, monthly) = try await (
                summaryRows,
                categoryRows,
                monthlyRows
            )
            let mappedSummary = Self.mapSummary(summary)
            return DashboardRemoteSnapshot(
                totalBalance: mappedSummary.totalBalance,
                periodExpenses: mappedSummary.periodExpenses,
                periodIncome: mappedSummary.periodIncome,
                expensesByCategory: categories.map(Self.mapCategoryTotal),
                weekdayExpenses: [],
                monthlyByKind: monthly.map(Self.mapMonthlyKindTotal)
            )
        }
    }

    private func resolveTimeZone(
        fallbackTimeZone: TimeZone,
        explicitOverride: String?
    ) async throws -> ResolvedDashboardTimeZone {
        if let explicitOverride, !explicitOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ResolvedDashboardTimeZone(
                calendarTimeZone: TimeZone(identifier: explicitOverride) ?? fallbackTimeZone,
                requestOverride: explicitOverride
            )
        }

        let rows = try await remoteStore.fetchProfileTimezone()
        if let timezone = rows.first?.timezone,
           !timezone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let resolved = TimeZone(identifier: timezone) {
            return ResolvedDashboardTimeZone(
                calendarTimeZone: resolved,
                requestOverride: nil
            )
        }

        return ResolvedDashboardTimeZone(
            calendarTimeZone: fallbackTimeZone,
            requestOverride: nil
        )
    }

    private static func makeRequest(
        filter: PeriodFilter,
        timeZone: TimeZone,
        today: Date,
        timezoneOverride: String?
    ) -> DashboardAggregateRequest {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let range = filter.dateRange(calendar: calendar, today: today)
        return DashboardAggregateRequest(
            fromDate: localDayString(range.from, timeZone: timeZone),
            toDate: localDayString(range.to, timeZone: timeZone),
            timezoneOverride: timezoneOverride
        )
    }

    private static func localDayString(
        _ date: Date,
        timeZone: TimeZone
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func mapSummary(_ rows: [DashboardSummaryRow]) -> (
        totalBalance: Decimal,
        periodExpenses: Decimal,
        periodIncome: Decimal
    ) {
        let row = rows.first ?? DashboardSummaryRow(
            totalBalanceCents: 0,
            periodExpenseCents: 0,
            periodIncomeCents: 0
        )
        return (
            Converters.centsToDecimal(row.totalBalanceCents),
            Converters.centsToDecimal(row.periodExpenseCents),
            Converters.centsToDecimal(row.periodIncomeCents)
        )
    }

    private static func mapCategoryTotal(_ row: DashboardCategoryTotalRow) -> CategoryTotal {
        CategoryTotal(
            categoryId: row.categoryId,
            categoryName: row.categoryName,
            icon: row.categorySlug.flatMap(CategoryIcon.forSlug),
            total: Converters.centsToDecimal(row.totalCents)
        )
    }

    private static func mapWeekdayTotal(_ row: DashboardWeekdayTotalRow) -> WeekdayTotal {
        WeekdayTotal(
            weekday: row.weekday,
            total: Converters.centsToDecimal(row.totalCents),
            count: row.count
        )
    }

    private static func mapMonthlyKindTotal(_ row: DashboardMonthlyKindTotalRow) -> MonthlyKindTotal {
        MonthlyKindTotal(
            monthStart: row.monthStart,
            income: Converters.centsToDecimal(row.incomeCents),
            expense: Converters.centsToDecimal(row.expenseCents)
        )
    }
}

struct StaticDashboardRemoteRepository: DashboardRemoteRepositoryProtocol {
    let snapshot: DashboardRemoteSnapshot

    func load(
        filter _: PeriodFilter,
        timeZone _: TimeZone,
        today _: Date,
        timezoneOverride _: String?
    ) async throws -> DashboardRemoteSnapshot {
        snapshot
    }
}

struct AuthRequiredDashboardRemoteRepository: DashboardRemoteRepositoryProtocol {
    func load(
        filter _: PeriodFilter,
        timeZone _: TimeZone,
        today _: Date,
        timezoneOverride _: String?
    ) async throws -> DashboardRemoteSnapshot {
        throw DashboardRemoteRepositoryError.authenticationRequired
    }
}
