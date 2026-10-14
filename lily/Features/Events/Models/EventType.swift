import Foundation

/// What kind of activity an event, group or tournament is; `other` covers anything the list does not name yet. Wire
/// names are the backend's lower-cased constant names, so a multi-word type travels in snake_case (`table_tennis`). A
/// type this build does not know is kept by name: it draws as Other, is never offered in a chip or picker and goes back
/// out as it came, so a payload from a newer backend still decodes.
nonisolated enum EventType: WireNamedKind {
    case football, basketball, tennis, padel, running, volleyball, cycling, climbing, yoga, swimming
    case tableTennis, badminton, martialArts, fitness, skiing, hiking, travel, esports, boardGames
    case other
    /// A type this build does not know, kept by name.
    case unknown(String)

    /// The types this build offers in chips and pickers, Other last; a type a newer backend sends is never among them.
    static let known: [EventType] = [
        .football, .basketball, .tennis, .padel, .running, .volleyball, .cycling, .climbing, .yoga, .swimming,
        .tableTennis, .badminton, .martialArts, .fitness, .skiing, .hiking, .travel, .esports, .boardGames, .other,
    ]

    private static let byWireName: [String: EventType] = Dictionary(uniqueKeysWithValues: known.map { ($0.wireName, $0) })

    init(wireName: String) {
        self = Self.byWireName[wireName] ?? .unknown(wireName)
    }

    /// The backend's lower-cased constant name; an unknown type's is the one it came with.
    var wireName: String {
        switch self {
        case .football: "football"
        case .basketball: "basketball"
        case .tennis: "tennis"
        case .padel: "padel"
        case .running: "running"
        case .volleyball: "volleyball"
        case .cycling: "cycling"
        case .climbing: "climbing"
        case .yoga: "yoga"
        case .swimming: "swimming"
        case .tableTennis: "table_tennis"
        case .badminton: "badminton"
        case .martialArts: "martial_arts"
        case .fitness: "fitness"
        case .skiing: "skiing"
        case .hiking: "hiking"
        case .travel: "travel"
        case .esports: "esports"
        case .boardGames: "board_games"
        case .other: "other"
        case .unknown(let name): name
        }
    }

    var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }

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
        case .other, .unknown: localized("Other")
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
        case .other, .unknown: "figure.mixed.cardio"
        }
    }
}
