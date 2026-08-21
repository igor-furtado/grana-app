import Foundation
import Observation
import OSLog

/// Estado observável do Dashboard com snapshots remotos por período explícito.
@MainActor
@Observable
final class DashboardStore {
    private let container: AppContainer
    private let todayProvider: @Sendable () -> Date
    private let timeZoneProvider: @Sendable () -> TimeZone

    /// Filtro de período corrente. `didSet` dispara `refresh()` em background
    /// — padrão SwiftUI-friendly: a View binda `$store.filter` no Picker e
    /// trocas do usuário re-disparam o cálculo automaticamente.
    ///
    /// Cada troca cancela o `refreshTask` anterior. Sem isso, alternar
    /// rapidamente entre presets ("mês atual" → "6 meses" → "12 meses")
    /// dispara refreshes concorrentes cuja ordem de retorno não é garantida
    /// — o estado podia ficar com `expensesByCategory` de uma chamada
    /// intermediária enquanto `monthlyByKind` era do filtro final.
    var filter: PeriodFilter = .currentMonth {
        didSet {
            refreshTask?.cancel()
            refreshTask = Task { [weak self] in
                await self?.refresh()
            }
        }
    }

    private var refreshTask: Task<Void, Never>?

    private(set) var totalBalance: Decimal = 0
    private(set) var periodExpenses: Decimal = 0
    private(set) var periodIncome: Decimal = 0
    /// Sempre 0 até a Fase 6 (Investimentos). O card mostra "—" via flag
    /// `placeholder` no `MetricCard` enquanto a feature não chega.
    private(set) var investmentValue: Decimal = 0
    /// Acumulado de despesas por categoria raiz, sempre populado — em
    /// `singleMonth` usa a janela do mês, em `multiMonth` usa os 6/12 meses.
    /// O mesmo `CategoryBarChart` consome em ambos os modos.
    private(set) var expensesByCategory: [CategoryTotal] = []
    /// Populadas só em `scope == .singleMonth`. Zeradas no multi-mês pra
    /// evitar estado stale (ex: usuário alterna "mês atual" → "12 meses" →
    /// "mês atual" e veria momentaneamente os dados anteriores).
    private(set) var weekdayExpenses: [WeekdayTotal] = []
    /// Populadas só em `scope == .multiMonth`. Mesma lógica de zeramento.
    private(set) var monthlyByKind: [MonthlyKindTotal] = []
    private(set) var isLoading = false
    var lastError: Error?

    init(
        container: AppContainer,
        todayProvider: @escaping @Sendable () -> Date = Date.init,
        timeZoneProvider: @escaping @Sendable () -> TimeZone = { .current }
    ) {
        self.container = container
        self.todayProvider = todayProvider
        self.timeZoneProvider = timeZoneProvider
    }

    func load() async {
        await refresh()
    }

    /// Recarrega os agregados remotos do dashboard com período explícito.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await container.remoteDashboard.load(
                filter: filter,
                timeZone: timeZoneProvider(),
                today: todayProvider(),
                timezoneOverride: nil
            )

            totalBalance = snapshot.totalBalance
            periodExpenses = snapshot.periodExpenses
            periodIncome = snapshot.periodIncome
            expensesByCategory = snapshot.expensesByCategory
            weekdayExpenses = snapshot.weekdayExpenses
            monthlyByKind = snapshot.monthlyByKind

            lastError = nil
        } catch {
            clearDisplayedData()
            lastError = error
            NoticeCenter.shared.report(error)
        }
    }

    private func clearDisplayedData() {
        totalBalance = 0
        periodExpenses = 0
        periodIncome = 0
        investmentValue = 0
        expensesByCategory = []
        weekdayExpenses = []
        monthlyByKind = []
    }
}
