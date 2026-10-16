import Foundation
import Testing
@testable import lily

/// The launch arguments only the UI tests set: `-hold-popups` keeps the error popup up until it is dismissed and
/// `-freeze-aurora` stops the aurora's redraw; without them the defaults hold.
@MainActor
struct AppDependenciesKnobsTests {
    private let flags = AppConfig.LaunchArguments.self

    @Test func holdPopupsDisablesTheAutoDismissAndTheDefaultKeepsIt() {
        let held = AppDependencies.makeDefault(arguments: [flags.mockEvents, flags.holdPopups], defaults: makeTestDefaults())
        #expect(held.errorCenter.autoDismissDelay == nil)

        let plain = AppDependencies.makeDefault(arguments: [flags.mockEvents], defaults: makeTestDefaults())
        #expect(plain.errorCenter.autoDismissDelay == AppConfig.ErrorPopup.autoDismissDelay)
    }

    @Test func freezeAuroraIsReadFromTheArgumentsAlone() {
        let frozen = AppDependencies.makeDefault(arguments: [flags.mockEvents, flags.freezeAurora], defaults: makeTestDefaults())
        #expect(frozen.freezesAurora)

        let plain = AppDependencies.makeDefault(arguments: [flags.mockEvents], defaults: makeTestDefaults())
        #expect(!plain.freezesAurora)
    }

    @Test func theMockRootKeepsTheDefaults() {
        let mock = AppDependencies.makeMock()
        #expect(mock.errorCenter.autoDismissDelay == AppConfig.ErrorPopup.autoDismissDelay)
        #expect(!mock.freezesAurora)
    }
}
