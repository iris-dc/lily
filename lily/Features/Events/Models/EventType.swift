import Foundation

/// What kind of activity an event, group or tournament is; `other` covers anything the list does not name yet. Wire
/// names are the backend's lower-cased constant names, so a multi-word type travels in snake_case (`table_tennis`). A
/// type this build does not know is kept by name: it draws as Other, is never offered in a chip or picker and goes back
/// out as it came, so a payload from a newer backend still decodes.
nonisolated enum EventType: WireNamedKind {
    case football, basketball, tennis, padel, running, volleyball, cycling, climbing, yoga, swimming
    case tableTennis, badminton, martialArts, fitness, skiing, hiking, travel, esports, boardGames
    case squash, golf, surfing, skateboarding, dance, boxing, rowing, sailing, chess, darts
    case bowling, pickleball, handball, hockey
    case other
    /// A type this build does not know, kept by name.
    case unknown(String)

    /// The types this build offers in chips and pickers, Other last; a type a newer backend sends is never among them.
    static let known: [EventType] = [
        .football, .basketball, .tennis, .padel, .running, .volleyball, .cycling, .climbing, .yoga, .swimming,
        .tableTennis, .badminton, .martialArts, .fitness, .skiing, .hiking, .travel, .esports, .boardGames,
        .squash, .golf, .surfing, .skateboarding, .dance, .boxing, .rowing, .sailing, .chess, .darts,
        .bowling, .pickleball, .handball, .hockey, .other,
    ]

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
        case .squash: "squash"
        case .golf: "golf"
        case .surfing: "surfing"
        case .skateboarding: "skateboarding"
        case .dance: "dance"
        case .boxing: "boxing"
        case .rowing: "rowing"
        case .sailing: "sailing"
        case .chess: "chess"
        case .darts: "darts"
        case .bowling: "bowling"
        case .pickleball: "pickleball"
        case .handball: "handball"
        case .hockey: "hockey"
        case .other: "other"
        case .unknown(let name): name
        }
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
        case .squash: localized("Squash")
        case .golf: localized("Golf")
        case .surfing: localized("Surfing")
        case .skateboarding: localized("Skateboarding")
        case .dance: localized("Dance")
        case .boxing: localized("Boxing")
        case .rowing: localized("Rowing")
        case .sailing: localized("Sailing")
        case .chess: localized("Chess")
        case .darts: localized("Darts")
        case .bowling: localized("Bowling")
        case .pickleball: localized("Pickleball")
        case .handball: localized("Handball")
        case .hockey: localized("Hockey")
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
        case .squash: "figure.squash"
        case .golf: "figure.golf"
        case .surfing: "figure.surfing"
        case .skateboarding: "skateboard"
        case .dance: "figure.dance"
        case .boxing: "figure.boxing"
        case .rowing: "figure.rower"
        case .sailing: "figure.sailing"
        case .chess: "checkerboard.rectangle"
        case .darts: "target"
        case .bowling: "figure.bowling"
        case .pickleball: "figure.pickleball"
        case .handball: "figure.handball"
        case .hockey: "figure.hockey"
        case .other, .unknown: "figure.mixed.cardio"
        }
    }
}
