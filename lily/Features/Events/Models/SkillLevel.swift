import Foundation

/// How experienced the host wants participants to be. Absent on an event means any level is welcome. A level this
/// build does not know keeps its name, counts as none (`ifKnown`) and goes back out as it came, so an event from a
/// newer backend still decodes instead of failing the payload.
nonisolated enum SkillLevel: WireNamedKind {
    case beginner, intermediate, advanced
    case unknown(String)

    /// The levels the pickers offer; an unknown one is never among them.
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

    /// `self` for a level this build can name, `nil` for an unknown one, so a site that treats such a level like none
    /// reads one optional.
    var ifKnown: SkillLevel? { isUnknown ? nil : self }

    /// An unknown level reads as any level: all this build knows is that it is none it can name.
    var displayName: String {
        switch self {
        case .beginner: localized("Beginner")
        case .intermediate: localized("Intermediate")
        case .advanced: localized("Advanced")
        case .unknown: AppBranding.Events.anyLevel
        }
    }
}
