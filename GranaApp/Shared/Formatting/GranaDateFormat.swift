import Foundation

enum GranaDateFormat {
    private static let locale = Locale(identifier: "pt_BR")

    static func fullDate(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        string(from: date, format: "dd 'de' MMM yyyy", timeZone: timeZone)
    }

    static func dayMonth(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        string(from: date, format: "dd 'de' MMM", timeZone: timeZone)
    }

    static func monthYear(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        string(from: date, format: "MMM 'de' yyyy", timeZone: timeZone)
    }

    static func dateTime(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        string(from: date, format: "dd 'de' MMM yyyy, HH:mm", timeZone: timeZone)
    }

    static func shortMonth(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        string(from: date, format: "MMM", timeZone: timeZone)
    }

    // `DateFormatter` não é thread-safe; mantemos um cache por thread+fuso.
    private static func string(from date: Date, format: String, timeZone: TimeZone) -> String {
        formatter(format: format, timeZone: timeZone).string(from: date)
    }

    private static func formatter(format: String, timeZone: TimeZone) -> DateFormatter {
        let key = "GranaDateFormat.\(format).\(timeZone.identifier)"
        if let formatter = Thread.current.threadDictionary[key] as? DateFormatter {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }
}
