import Foundation

/// How experienced the host wants participants to be. Absent on an event means any level is welcome. A level this
/// build does not know keeps its name and counts as none (`ifKnown`): the detail says nothing of it, the filter lets
/// it pass every choice, no picker offers it, and it goes back out as it came, so an event from a newer backend still
/// decodes instead of failing the payload.
nonisolated enum SkillLevel: WireNamedKind {
    case beginner, intermediate, advanced
    /// A level this build does not know, kept by name.
    case unknown(String)

    /// The levels this build offers in the form's and the filter's pickers; a level a newer backend sends is never
    /// among them.
    static let known: [SkillLevel] = [.beginner, .intermediate, .advanced]

    private static let beginnerName = "beginner"
    private static let intermediateName = "intermediate"
    private static let advancedName = "advanced"

    init(wireName: String) {
        switch wireName {
        case Self.beginnerName: self = .beginner
        case Self.intermediateName: self = .intermediate
        case Self.advancedName: self = .advanced
        default: self = .unknown(wireName)
        }
    }

    var wireName: String {
        switch self {
        case .beginner: Self.beginnerName
        case .intermediate: Self.intermediateName
        case .advanced: Self.advancedName
        case .unknown(let name): name
        }
    }

    var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }

    /// `self` when this build can name the level, `nil` for one it does not know, so a site that treats such a level
    /// like none (the filter, the facts card, a restored filter) reads one optional.
    var ifKnown: SkillLevel? { isUnknown ? nil : self }

    /// Should a site name an unknown level, it reads as any level: all this build knows is that it is none it can name.
    var displayName: String {
        switch self {
        case .beginner: localized("Beginner")
        case .intermediate: localized("Intermediate")
        case .advanced: localized("Advanced")
        case .unknown: AppBranding.Events.Filter.anyLevel
        }
    }
}
