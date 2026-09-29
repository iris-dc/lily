import Foundation

/// The tabs of the main shell, in bar order. `AppNavigation.selectedTab` holds the current one; `chat` exists only
/// while `AppConfig.FeatureFlags.chat` is on.
nonisolated enum AppTab: Hashable, CaseIterable, Sendable {
    case home, explore, chat, profile
}
