import Foundation

/// The backend's `GroupSummary`: a group as a profile's "Groups in common" row shows it, enough for the row and the link.
nonisolated struct GroupSummary: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let visibility: GroupVisibility
    /// Absent means any sport.
    let type: EventType?
    let memberCount: Int

    init(id: String, name: String, visibility: GroupVisibility, type: EventType? = nil, memberCount: Int) {
        self.id = id
        self.name = name
        self.visibility = visibility
        self.type = type
        self.memberCount = memberCount
    }

    /// A group the caller holds in full, reduced to its summary (the mock profiles).
    init(_ group: SportGroup) {
        self.init(id: group.id, name: group.name, visibility: group.visibility, type: group.type, memberCount: group.memberCount)
    }

    /// "34 members · Football", as a group's own row captions it.
    var caption: String {
        AppBranding.Groups.groupCaption(memberCount: memberCount, type: type)
    }

    /// The reference the row pushes: the shared `EventGroupRef` destination fetches the group and shows its detail.
    var ref: EventGroupRef {
        EventGroupRef(id: id, name: name, visibility: visibility, isDeleted: false)
    }
}
