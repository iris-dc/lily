import Foundation

/// The part of the day a game starts in, as the filter buckets it: before noon, noon to six, six onward. Judged in
/// the calendar the user reads the start in, so "Morning" means the player's morning.
nonisolated enum TimeOfDay: String, CaseIterable, Codable, Sendable {
    case morning
    case afternoon
    case evening

    static func of(_ date: Date, calendar: Calendar = .current) -> TimeOfDay {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case ..<AppConfig.Events.afternoonStartHour: return .morning
        case ..<AppConfig.Events.eveningStartHour: return .afternoon
        default: return .evening
        }
    }

    var displayName: String {
        switch self {
        case .morning: localized("Morning")
        case .afternoon: localized("Afternoon")
        case .evening: localized("Evening")
        }
    }
}
