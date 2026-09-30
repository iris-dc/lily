import Foundation

nonisolated extension SportGroup {
    /// "34 members · Football", with `suffix` appended when given ("Active today" on a row, "Joined" on a tile). A
    /// direct conversation has no count or type worth a caption and reads "Direct message" instead.
    func caption(suffix: String? = nil) -> String {
        guard isDirect else {
            return AppBranding.Groups.groupCaption(memberCount: memberCount, type: type, suffix: suffix)
        }
        var parts = [AppBranding.People.directMessage]
        if let suffix { parts.append(suffix) }
        return AppBranding.Groups.caption(parts)
    }
}
