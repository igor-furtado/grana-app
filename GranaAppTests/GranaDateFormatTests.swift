import Foundation
import Testing
@testable import GranaApp

@Suite("GranaDateFormat")
struct GranaDateFormatTests {
    @Test("Formata data completa no locale pt-BR")
    func fullDate() throws {
        let fortaleza = try fortalezaTimeZone()
        let date = try #require(utcDate(year: 2026, month: 8, day: 30, hour: 10, minute: 15))

        #expect(GranaDateFormat.fullDate(date, timeZone: fortaleza) == "30 de ago. 2026")
    }

    @Test("Formata dia e mes sem ano")
    func dayMonth() throws {
        let fortaleza = try fortalezaTimeZone()
        let date = try #require(utcDate(year: 2026, month: 8, day: 30, hour: 10, minute: 15))

        #expect(GranaDateFormat.dayMonth(date, timeZone: fortaleza) == "30 de ago.")
    }

    @Test("Formata mes e ano abreviado")
    func monthYear() throws {
        let fortaleza = try fortalezaTimeZone()
        let date = try #require(utcDate(year: 2026, month: 8, day: 30, hour: 10, minute: 15))

        #expect(GranaDateFormat.monthYear(date, timeZone: fortaleza) == "ago. de 2026")
    }

    @Test("Formata data e hora no fuso informado")
    func dateTime() throws {
        let fortaleza = try fortalezaTimeZone()
        let date = try #require(utcDate(year: 2026, month: 8, day: 30, hour: 10, minute: 15))

        #expect(GranaDateFormat.dateTime(date, timeZone: fortaleza) == "30 de ago. 2026, 07:15")
    }

    @Test("Formata mes curto isolado")
    func shortMonth() throws {
        let fortaleza = try fortalezaTimeZone()
        let date = try #require(utcDate(year: 2026, month: 9, day: 1, hour: 0, minute: 0))

        #expect(GranaDateFormat.shortMonth(date, timeZone: fortaleza) == "ago.")
    }

    @Test("Respeita o timezone na virada do dia")
    func timezoneBoundary() throws {
        let fortaleza = try fortalezaTimeZone()
        let date = try #require(utcDate(year: 2026, month: 8, day: 30, hour: 1, minute: 0))

        #expect(GranaDateFormat.fullDate(date, timeZone: fortaleza) == "29 de ago. 2026")
    }

    @Test("Formata date-only sem deslocar para o dia anterior no fuso local")
    func dateOnlyDoesNotShiftToPreviousLocalDay() throws {
        let date = try #require(utcDate(year: 2025, month: 8, day: 1, hour: 0, minute: 0))

        #expect(GranaDateFormat.dateOnlyDayMonth(date) == "01 de ago.")
        #expect(GranaDateFormat.dateOnlyMonthYear(date) == "ago. de 2025")
        #expect(GranaDateFormat.dateOnlyShortMonth(date) == "ago.")
    }

    private func fortalezaTimeZone() throws -> TimeZone {
        try #require(TimeZone(identifier: "America/Fortaleza"))
    }

    private func utcDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date
    }
}
