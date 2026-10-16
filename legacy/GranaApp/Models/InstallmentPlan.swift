import Foundation

struct InstallmentPlan: Codable, Hashable {
    let index: Int
    let count: Int

    init?(index: Int, count: Int) {
        guard index >= 1, count >= 2, index <= count else { return nil }
        self.index = index
        self.count = count
    }

    static let `default` = InstallmentPlan(index: 1, count: 2)!

    static func normalized(index: Int, count: Int) -> InstallmentPlan {
        let normalizedCount = max(2, count)
        let normalizedIndex = min(max(1, index), normalizedCount)
        return InstallmentPlan(index: normalizedIndex, count: normalizedCount)!
    }

    func updatingIndex(_ index: Int) -> InstallmentPlan {
        Self.normalized(index: index, count: count)
    }

    func updatingCount(_ count: Int) -> InstallmentPlan {
        Self.normalized(index: index, count: count)
    }

    func originOccurredAt(for occurredAt: Date, calendar: Calendar) -> Date {
        calendar.date(
            byAdding: .month,
            value: 1 - index,
            to: occurredAt
        ) ?? occurredAt
    }
}
