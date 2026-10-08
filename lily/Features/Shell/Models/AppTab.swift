import Foundation

/// The tabs of the main shell, in bar order. `AppNavigation.selectedTab` holds the current one; `chat` exists only
/// while `AppConfig.FeatureFlags.chat` is on.
nonisolated enum AppTab: Hashable, CaseIterable, Sendable {
    case home, explore, chat, profile

    /// The tabs the shell draws, in bar order: the ⌘1 to ⌘4 shortcuts follow this list, so the numbers never skip.
    static var shown: [AppTab] {
        allCases.filter { $0 != .chat || AppConfig.FeatureFlags.chat }
    }

    /// The tab's title, which is also its root's navigation title.
    var title: String {
        switch self {
        case .home: AppBranding.homeTitle
        case .explore: AppBranding.exploreTitle
        case .chat: AppBranding.chatsTitle
        case .profile: AppBranding.profileTitle
        }
    }
}
