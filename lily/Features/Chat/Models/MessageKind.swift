import Foundation

/// What a chat row is: something a member wrote, or a system note the backend posted (a game created in the group).
/// A kind this build does not know keeps its name and counts as a system note that `ChatTimeline` leaves out, so a
/// room from a newer backend still decodes and shows nothing for it rather than a wrong line.
nonisolated enum MessageKind: WireNamedKind {
    case text
    case eventCreated
    case unknown(String)

    private static let textName = "text"
    private static let eventCreatedName = "event_created"

    init(wireName: String) {
        switch wireName {
        case Self.textName: self = .text
        case Self.eventCreatedName: self = .eventCreated
        default: self = .unknown(wireName)
        }
    }

    var wireName: String {
        switch self {
        case .text: Self.textName
        case .eventCreated: Self.eventCreatedName
        case .unknown(let name): name
        }
    }

    var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }
}
