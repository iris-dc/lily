import Foundation

/// The two segments under a group's header.
nonisolated enum GroupDetailSection: Hashable, CaseIterable, Sendable {
    case events, members

    var title: String {
        switch self {
        case .events: AppBranding.Groups.eventsSection
        case .members: AppBranding.Groups.membersSection
        }
    }
}
