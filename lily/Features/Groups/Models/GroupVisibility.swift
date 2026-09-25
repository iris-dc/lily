import Foundation

/// Who can find and join a group. Immutable once created.
nonisolated enum GroupVisibility: String, CaseIterable, Codable, Sendable {
    /// Anyone can find and join.
    case `public`
    /// Only people with an invite can join; non-members are told the group does not exist.
    case `private`

    var displayName: String {
        switch self {
        case .public: AppBranding.Groups.publicVisibility
        case .private: AppBranding.Groups.privateVisibility
        }
    }

    var symbolName: String {
        switch self {
        case .public: DesignTokens.Symbols.publicGroup
        case .private: DesignTokens.Symbols.privateGroup
        }
    }
}
