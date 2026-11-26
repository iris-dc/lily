import Foundation
import Testing
@testable import lily

@MainActor
struct NotificationPreferencesTests {
    private let defaults = makeTestDefaults()

    @Test func startsWithEverythingEnabledAndPersistsFlips() {
        let preferences = NotificationPreferences(defaults: defaults)
        #expect(NotificationKind.allCases.allSatisfy { preferences.isEnabled($0) })

        preferences.set(.matchReminder, enabled: false)
        preferences.set(.eventReminder, enabled: false)
        preferences.set(.matchReminder, enabled: true)

        #expect(preferences.mutedWireNames == ["event_reminder"])
        #expect(!preferences.isEnabled(.eventReminder) && preferences.isEnabled(.matchReminder))
        #expect(NotificationPreferences(defaults: defaults).mutedWireNames == ["event_reminder"],
                "a relaunch reads the mutes back")
    }

    /// A kind this build does not know is dropped on read, like an unknown stored choice.
    @Test func unknownStoredKindsAreDropped() {
        defaults.set(["event_reminder", "carrier_pigeon"], forKey: AppConfig.Push.mutedKindsKey)

        #expect(NotificationPreferences(defaults: defaults).mutedWireNames == ["event_reminder"])
    }

    @Test func wireNamesAreSorted() {
        let preferences = NotificationPreferences(defaults: defaults)

        preferences.set(.matchReminder, enabled: false)
        preferences.set(.eventCancelled, enabled: false)

        #expect(preferences.mutedWireNames == ["event_cancelled", "match_reminder"])
    }
}
