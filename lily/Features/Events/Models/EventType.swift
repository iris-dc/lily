import Foundation

/// What kind of activity an event is. `other` covers anything the list does not name yet. Multi-word types carry the
/// backend's snake_case wire name (Laurel lower-cases its constant names), so `tableTennis` travels as `table_tennis`.
nonisolated enum EventType: String, CaseIterable, Codable, Sendable {
    case football, basketball, tennis, padel, running, volleyball, cycling, climbing, yoga
    case swimming
    case tableTennis = "table_tennis"
    case badminton
    case martialArts = "martial_arts"
    case fitness, skiing, hiking, travel, esports
    case boardGames = "board_games"
    case other

    var displayName: String {
        switch self {
        case .football: localized("Football")
        case .basketball: localized("Basketball")
        case .tennis: localized("Tennis")
        case .padel: localized("Padel")
        case .running: localized("Running")
        case .volleyball: localized("Volleyball")
        case .cycling: localized("Cycling")
        case .climbing: localized("Climbing")
        case .yoga: localized("Yoga")
        case .swimming: localized("Swimming")
        case .tableTennis: localized("Table tennis")
        case .badminton: localized("Badminton")
        case .martialArts: localized("Martial arts")
        case .fitness: localized("Fitness")
        case .skiing: localized("Skiing")
        case .hiking: localized("Hiking")
        case .travel: localized("Travel")
        case .esports: localized("Esports")
        case .boardGames: localized("Board games")
        case .other: localized("Other")
        }
    }

    var symbolName: String {
        switch self {
        case .football: "figure.indoor.soccer"
        case .basketball: "figure.basketball"
        case .tennis: "figure.tennis"
        case .padel: "figure.pickleball"
        case .running: "figure.run"
        case .volleyball: "figure.volleyball"
        case .cycling: "figure.outdoor.cycle"
        case .climbing: "figure.climbing"
        case .yoga: "figure.yoga"
        case .swimming: "figure.pool.swim"
        case .tableTennis: "figure.table.tennis"
        case .badminton: "figure.badminton"
        case .martialArts: "figure.martial.arts"
        case .fitness: "figure.strengthtraining.traditional"
        case .skiing: "figure.skiing.downhill"
        case .hiking: "figure.hiking"
        case .travel: "airplane"
        case .esports: "gamecontroller"
        case .boardGames: "dice"
        case .other: "figure.mixed.cardio"
        }
    }
}
