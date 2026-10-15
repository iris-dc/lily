import Foundation
import Testing
@testable import lily

/// `-hold-popups` keeps the error popup up until it is dismissed; without it the popup fades after the configured delay.
@MainActor
struct AppDependenciesPopupTests {
    @Test func holdPopupsDisablesTheAutoDismissAndTheDefaultKeepsIt() {
        let flags = AppConfig.LaunchArguments.self
        let held = AppDependencies.makeDefault(arguments: [flags.mockEvents, flags.holdPopups], defaults: makeTestDefaults())
        #expect(held.errorCenter.autoDismissDelay == nil)

        let plain = AppDependencies.makeDefault(arguments: [flags.mockEvents], defaults: makeTestDefaults())
        #expect(plain.errorCenter.autoDismissDelay == AppConfig.ErrorPopup.autoDismissDelay)
    }

    @Test func theMockRootKeepsTheDefaultDelay() {
        #expect(AppDependencies.makeMock().errorCenter.autoDismissDelay == AppConfig.ErrorPopup.autoDismissDelay)
    }
}
