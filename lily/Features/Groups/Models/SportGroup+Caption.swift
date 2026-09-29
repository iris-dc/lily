import Foundation

nonisolated extension SportGroup {
    /// "34 members · Football", with `suffix` appended when given ("Active today" on a row, "Joined" on a tile).
    func caption(suffix: String? = nil) -> String {
        var parts = [AppBranding.Groups.members(memberCount)]
        if let type { parts.append(type.displayName) }
        if let suffix { parts.append(suffix) }
        return AppBranding.Groups.caption(parts)
    }
}
