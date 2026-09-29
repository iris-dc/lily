import Foundation

/// The tabs of the main shell, in bar order. `AppNavigation.selectedTab` holds the current one.
nonisolated enum AppTab: Hashable, CaseIterable, Sendable {
    case home, explore, profile
}
