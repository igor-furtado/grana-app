import Foundation
import Testing
@testable import GranaAi

@Suite("DashboardRemoteRepository")
struct DashboardRemoteRepositoryTests {
    @Test("Usa timezone do perfil por padrão ao montar período explícito")
    func usesProfileTimezoneByDefault() async throws {
        let store = FakeDashboardRemoteStore(
            profileTimezoneRows: [
                DashboardProfileTimezoneRow(timezone: "America/Los_Angeles"),
            ],
            summaryRows: [
                DashboardSummaryRow(
                    totalBalanceCents: 123_456,
                    periodExpenseCents: 4_550,
                    periodIncomeCents: 9_100
                ),
            ],
            categoryRows: [
                DashboardCategoryTotalRow(
                    categoryId: UUID(),
                    categoryName: "Alimentação",
                    categorySlug: "alimentacao",
                    totalCents: 4_550
                ),
            ],
            weekdayRows: [
                DashboardWeekdayTotalRow(
                    weekday: 6,
                    totalCents: 4_550,
                    count: 2
                ),
            ]
        )
        let repository = DashboardRemoteRepository(remoteStore: store)

        let snapshot = try await repository.load(
            filter: .currentMonth,
            timeZone: .gmt,
            today: makeDate(year: 2026, month: 8, day: 1, hour: 1),
            timezoneOverride: nil
        )

        #expect(snapshot.totalBalance == Decimal(string: "1234.56"))
        #expect(snapshot.periodExpenses == Decimal(string: "45.50"))
        #expect(snapshot.periodIncome == 91)
        #expect(snapshot.expensesByCategory.map(\.categoryName) == ["Alimentação"])
        #expect(snapshot.weekdayExpenses.first?.weekday == 6)
        #expect(snapshot.weekdayExpenses.first?.count == 2)
        #expect(snapshot.monthlyByKind.isEmpty)

        let requests = await store.recordedRequests()
        #expect(requests.summary == [
            DashboardAggregateRequest(
                fromDate: "2026-07-01",
                toDate: "2026-07-31",
                timezoneOverride: nil
            ),
        ])
        #expect(requests.categories == requests.summary)
        #expect(requests.weekdays == requests.summary)
        #expect(requests.monthly.isEmpty)
        #expect(requests.profileTimezones == 1)
    }

    @Test("Mapeia série multi-mês e envia override de timezone")
    func mapsMultiMonthSnapshotAndTimezoneOverride() async throws {
        let monthStart = makeDate(year: 2026, month: 8, day: 1)
        let store = FakeDashboardRemoteStore(
            summaryRows: [
                DashboardSummaryRow(
                    totalBalanceCents: 88_000,
                    periodExpenseCents: 15_000,
                    periodIncomeCents: 21_000
                ),
            ],
            categoryRows: [
                DashboardCategoryTotalRow(
                    categoryId: UUID(),
                    categoryName: "Moradia",
                    categorySlug: "moradia",
                    totalCents: 15_000
                ),
            ],
            monthlyRows: [
                DashboardMonthlyKindTotalRow(
                    monthStart: monthStart,
                    incomeCents: 21_000,
                    expenseCents: 15_000
                ),
            ]
        )
        let repository = DashboardRemoteRepository(remoteStore: store)

        let snapshot = try await repository.load(
            filter: .last6Months,
            timeZone: .gmt,
            today: makeDate(year: 2026, month: 8, day: 21, hour: 9),
            timezoneOverride: "America/Sao_Paulo"
        )

        #expect(snapshot.totalBalance == 880)
        #expect(snapshot.periodExpenses == 150)
        #expect(snapshot.periodIncome == 210)
        #expect(snapshot.expensesByCategory.map(\.categoryName) == ["Moradia"])
        #expect(snapshot.weekdayExpenses.isEmpty)
        #expect(snapshot.monthlyByKind.count == 1)
        #expect(snapshot.monthlyByKind.first?.monthStart == monthStart)

        let requests = await store.recordedRequests()
        #expect(requests.summary == [
            DashboardAggregateRequest(
                fromDate: "2026-03-01",
                toDate: "2026-08-21",
                timezoneOverride: "America/Sao_Paulo"
            ),
        ])
        #expect(requests.categories == requests.summary)
        #expect(requests.monthly == requests.summary)
        #expect(requests.weekdays.isEmpty)
        #expect(requests.profileTimezones == 0)
    }
}

@MainActor
@Suite("DashboardStoreRemote")
struct DashboardStoreRemoteTests {
    @Test("Load usa agregações remotas em vez do histórico local")
    func loadUsesRemoteAggregations() async throws {
        let snapshot = DashboardRemoteSnapshot(
            totalBalance: 321,
            periodExpenses: 45,
            periodIncome: 67,
            expensesByCategory: [
                CategoryTotal(
                    categoryId: UUID(),
                    categoryName: "Alimentação",
                    icon: .food,
                    total: 45
                ),
            ],
            weekdayExpenses: [
                WeekdayTotal(weekday: 2, total: 45, count: 1),
            ],
            monthlyByKind: []
        )
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: []),
            remoteDashboard: StaticDashboardRemoteRepository(snapshot: snapshot)
        )
        let now = makeDate(year: 2026, month: 8, day: 21, hour: 10)
        let account = Account(
            id: UUID(),
            type: .checking,
            initialBalance: 9_999,
            archived: false,
            createdAt: now,
            updatedAt: now
        )
        try await container.accounts.insert(account)
        try await container.transactions.insert(Transaction(
            id: UUID(),
            accountId: account.id,
            categoryId: UUID(),
            amount: 5_000,
            occurredAt: now,
            description: "PIX entre contas",
            destinationAccountId: UUID(),
            createdAt: now,
            updatedAt: now
        ))
        let store = DashboardStore(container: container)

        await store.load()

        #expect(store.totalBalance == 321)
        #expect(store.periodExpenses == 45)
        #expect(store.periodIncome == 67)
        #expect(store.expensesByCategory.map(\.categoryName) == ["Alimentação"])
        #expect(store.weekdayExpenses.map(\.weekday) == [2])
        #expect(store.monthlyByKind.isEmpty)
    }

    @Test("Refresh limpa dados stale quando o remoto falha")
    func refreshClearsStaleValuesAfterRemoteError() async {
        let initialSnapshot = DashboardRemoteSnapshot(
            totalBalance: 321,
            periodExpenses: 45,
            periodIncome: 67,
            expensesByCategory: [
                CategoryTotal(
                    categoryId: UUID(),
                    categoryName: "Alimentação",
                    icon: .food,
                    total: 45
                ),
            ],
            weekdayExpenses: [
                WeekdayTotal(weekday: 2, total: 45, count: 1),
            ],
            monthlyByKind: []
        )
        let repository = SequencedDashboardRemoteRepository(results: [
            .success(initialSnapshot),
            .failure(DashboardRemoteRepositoryError.authenticationRequired),
        ])
        let container = AppContainer.inMemoryForTesting(
            categoryCatalog: StaticCategoryCatalogRepository(categories: []),
            institutionCatalog: StaticInstitutionCatalogRepository(institutions: []),
            remoteDashboard: repository
        )
        let store = DashboardStore(container: container)

        await store.load()
        await store.refresh()

        #expect(store.lastError as? DashboardRemoteRepositoryError == .authenticationRequired)
        #expect(store.isLoading == false)
        #expect(store.totalBalance == 0)
        #expect(store.periodExpenses == 0)
        #expect(store.periodIncome == 0)
        #expect(store.expensesByCategory.isEmpty)
        #expect(store.weekdayExpenses.isEmpty)
        #expect(store.monthlyByKind.isEmpty)
    }
}

private actor FakeDashboardRemoteStore: DashboardRemoteStore {
    let profileTimezoneRows: [DashboardProfileTimezoneRow]
    let summaryRows: [DashboardSummaryRow]
    let categoryRows: [DashboardCategoryTotalRow]
    let weekdayRows: [DashboardWeekdayTotalRow]
    let monthlyRows: [DashboardMonthlyKindTotalRow]

    private var profileTimezoneRequests = 0
    private var summaryRequests: [DashboardAggregateRequest] = []
    private var categoryRequests: [DashboardAggregateRequest] = []
    private var weekdayRequests: [DashboardAggregateRequest] = []
    private var monthlyRequests: [DashboardAggregateRequest] = []

    init(
        profileTimezoneRows: [DashboardProfileTimezoneRow] = [],
        summaryRows: [DashboardSummaryRow] = [],
        categoryRows: [DashboardCategoryTotalRow] = [],
        weekdayRows: [DashboardWeekdayTotalRow] = [],
        monthlyRows: [DashboardMonthlyKindTotalRow] = []
    ) {
        self.profileTimezoneRows = profileTimezoneRows
        self.summaryRows = summaryRows
        self.categoryRows = categoryRows
        self.weekdayRows = weekdayRows
        self.monthlyRows = monthlyRows
    }

    func fetchProfileTimezone() async throws -> [DashboardProfileTimezoneRow] {
        profileTimezoneRequests += 1
        return profileTimezoneRows
    }

    func fetchSummary(request: DashboardAggregateRequest) async throws -> [DashboardSummaryRow] {
        summaryRequests.append(request)
        return summaryRows
    }

    func fetchExpenseCategoryTotals(request: DashboardAggregateRequest) async throws -> [DashboardCategoryTotalRow] {
        categoryRequests.append(request)
        return categoryRows
    }

    func fetchExpenseWeekdayTotals(request: DashboardAggregateRequest) async throws -> [DashboardWeekdayTotalRow] {
        weekdayRequests.append(request)
        return weekdayRows
    }

    func fetchMonthlyKindTotals(request: DashboardAggregateRequest) async throws -> [DashboardMonthlyKindTotalRow] {
        monthlyRequests.append(request)
        return monthlyRows
    }

    func recordedRequests() -> (
        profileTimezones: Int,
        summary: [DashboardAggregateRequest],
        categories: [DashboardAggregateRequest],
        weekdays: [DashboardAggregateRequest],
        monthly: [DashboardAggregateRequest]
    ) {
        (
            profileTimezoneRequests,
            summaryRequests,
            categoryRequests,
            weekdayRequests,
            monthlyRequests
        )
    }
}

private struct FailingDashboardRemoteRepository: DashboardRemoteRepositoryProtocol {
    let error: any Error

    func load(
        filter _: PeriodFilter,
        timeZone _: TimeZone,
        today _: Date,
        timezoneOverride _: String?
    ) async throws -> DashboardRemoteSnapshot {
        throw error
    }
}

private actor SequencedDashboardRemoteRepository: DashboardRemoteRepositoryProtocol {
    private var results: [Result<DashboardRemoteSnapshot, any Error>]

    init(results: [Result<DashboardRemoteSnapshot, any Error>]) {
        self.results = results
    }

    func load(
        filter _: PeriodFilter,
        timeZone _: TimeZone,
        today _: Date,
        timezoneOverride _: String?
    ) async throws -> DashboardRemoteSnapshot {
        let next = results.isEmpty
            ? .failure(DashboardRemoteRepositoryError.authenticationRequired)
            : results.removeFirst()
        return try next.get()
    }
}

private func makeDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar.date(from: DateComponents(
        timeZone: .gmt,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute,
        second: second
    )) ?? .distantPast
}
