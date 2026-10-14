import Foundation
import Testing
@testable import lily

/// The one date-and-time style of the facts cards and match rows follows the app language, not the device.
@MainActor
struct DateStylesTests {
    /// 2027-01-15 08:00 UTC: January in every time zone.
    private static let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func text(in identifier: String) -> String {
        Self.date.formatted(LilyTheme.DateStyles.dateTime(locale: Locale(identifier: identifier)))
    }

    @Test func theRegistrationDateFollowsTheAppLanguage() {
        let russian = text(in: "ru_RU")
        #expect(russian.contains("янв"))
        #expect(!russian.contains("Jan"))

        let english = text(in: "en_GB")
        #expect(english.contains("Jan"))
        #expect(!english.contains("янв"))
    }

    @Test func theStyleShowsDateAndTime() {
        let english = text(in: "en_GB")
        #expect(english.contains("2027"))
        #expect(english.contains(":"))
    }

    @Test func theDefaultStyleFollowsTheAppLocale() {
        #expect(LilyTheme.DateStyles.dateTime.locale == AppLocale.locale)
    }
}
