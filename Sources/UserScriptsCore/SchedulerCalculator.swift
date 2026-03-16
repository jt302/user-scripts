import Foundation

public struct SchedulerCalculator {
    public init() {}

    public func nextRunDate(for rule: SchedulerRule, after date: Date, calendar: Calendar) -> Date? {
        switch rule {
        case .disabled:
            return nil
        case let .interval(minutes):
            guard minutes > 0 else { return nil }
            return calendar.date(byAdding: .minute, value: minutes, to: date)
        case let .daily(hour, minute):
            guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let sameDay = calendar.date(from: components) else {
                return nil
            }

            if sameDay > date {
                return sameDay
            }

            return calendar.date(byAdding: .day, value: 1, to: sameDay)
        }
    }
}
