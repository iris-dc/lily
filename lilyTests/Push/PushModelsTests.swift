import Foundation
import Testing
@testable import lily

struct PushModelsTests {
    @Test func theTapIsReadFromAReminderPayloadOnly() {
        #expect(PushPayload.tap(from: ["kind": "event_reminder", "eventId": "e1"]) == .event(id: "e1"))
        #expect(PushPayload.tap(from: ["kind": "group_invite", "eventId": "e1"]) == nil)
        #expect(PushPayload.tap(from: ["kind": "event_reminder", "eventId": ""]) == nil)
        #expect(PushPayload.tap(from: ["kind": "event_reminder"]) == nil)
        #expect(PushPayload.tap(from: ["aps": ["alert": "x"]]) == nil)
    }

    /// Laurel's `MatchReminderPush` data: `{kind, tournamentId, matchId, inboxItemId}`; the item id is not needed to open.
    @Test func aMatchReminderNamesItsTournamentAndMatch() {
        let payload: [AnyHashable: Any] = ["kind": "match_reminder", "tournamentId": "t1", "matchId": "r01p002",
                                           "inboxItemId": "01ARYZ6S41TSV4RRFFQ69G5FAY"]
        #expect(PushPayload.tap(from: payload) == .match(tournamentID: "t1", matchID: "r01p002"))
        #expect(PushPayload.tap(from: ["kind": "match_reminder", "tournamentId": "t1"]) == nil, "a match is needed")
        #expect(PushPayload.tap(from: ["kind": "match_reminder", "tournamentId": "", "matchId": "r01p002"]) == nil)
        #expect(PushTap.match(tournamentID: "t1", matchID: "r01p002").logName == "match r01p002 of tournament t1")
        #expect(PushTap.event(id: "e1").logName == "event e1")
    }

    @Test func aRegistrationIsCurrentForTheSameTokenUserAndLanguageWithinTheInterval() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let registration = LastDeviceRegistration(token: "t", userID: "u", locale: "en", registeredAt: now)

        #expect(registration.isCurrent(token: "t", userID: "u", locale: "en", now: now.addingTimeInterval(3_599), within: 3_600))
        #expect(!registration.isCurrent(token: "t", userID: "u", locale: "en", now: now.addingTimeInterval(3_600), within: 3_600))
        #expect(!registration.isCurrent(token: "other", userID: "u", locale: "en", now: now, within: 3_600))
        #expect(!registration.isCurrent(token: "t", userID: "someone", locale: "en", now: now, within: 3_600))
        #expect(!registration.isCurrent(token: "t", userID: "u", locale: "ru", now: now, within: 3_600))
    }

    /// `PushCoordinator` keeps the registration in `UserDefaults` through a plain `JSONEncoder`/`JSONDecoder`, whose
    /// default writes a `Date` as seconds since the reference date; a row written before the app spoke more than one
    /// language is that shape without a `locale`.
    @Test func aRegistrationStoredBeforeTheAppSpokeLanguagesReadsWithoutOneAndIsNotCurrent() throws {
        let stored = try JSONDecoder().decode(LastDeviceRegistration.self, from: Data("""
        {"token":"t","userID":"u","registeredAt":780000000}
        """.utf8))
        #expect(stored.locale == nil)
        #expect(stored.registeredAt == Date(timeIntervalSinceReferenceDate: 780_000_000))
        #expect(!stored.isCurrent(token: "t", userID: "u", locale: "en", now: stored.registeredAt, within: 3_600))
    }

    @Test func aStoredRegistrationRoundTripsThroughTheCoordinatorsCoding() throws {
        let registration = LastDeviceRegistration(token: "t",
                                                  userID: "u",
                                                  locale: "en",
                                                  registeredAt: Date(timeIntervalSinceReferenceDate: 780_000_000))
        let data = try JSONEncoder().encode(registration)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"registeredAt\":780000000"))
        #expect(try JSONDecoder().decode(LastDeviceRegistration.self, from: data) == registration)
    }

    @Test func theCurrentEnvironmentIsTheSandboxInADebugBuild() {
        #if DEBUG
        #expect(PushEnvironment.current == .sandbox)
        #endif
    }

    @Test func thePayloadWritesLowerCaseWireNamesAndTheLocale() throws {
        let payload = DeviceRegistrationPayload(token: "ab",
                                                platform: "ios",
                                                environment: .sandbox,
                                                appVersion: "1.0 (42)",
                                                locale: "ru")
        let json = try #require(String(data: APIJSONCoding.makeEncoder().encode(payload), encoding: .utf8))
        #expect(json.contains("\"token\":\"ab\""))
        #expect(json.contains("\"platform\":\"ios\""))
        #expect(json.contains("\"environment\":\"sandbox\""))
        #expect(json.contains("\"appVersion\":\"1.0 (42)\""))
        #expect(json.contains("\"locale\":\"ru\""))
    }

    /// The API client reads the backend's ISO-8601 instants, with or without fractional seconds.
    @Test func aRegistrationDecodesFromTheBackendsShape() throws {
        let tenOnTheSecondOfOctober2026 = Date(timeIntervalSince1970: 1_790_935_200)
        let decoder = APIJSONCoding.makeDecoder()
        let registration = try decoder.decode(DeviceRegistration.self, from: Data("""
        {"token":"ab","environment":"production","registeredAt":"2026-10-02T10:00:00Z"}
        """.utf8))
        #expect(registration.environment == .production)
        #expect(registration.token == "ab")
        #expect(registration.registeredAt == tenOnTheSecondOfOctober2026)

        let fractional = try decoder.decode(DeviceRegistration.self, from: Data("""
        {"token":"ab","environment":"production","registeredAt":"2026-10-02T10:00:00.250Z"}
        """.utf8))
        #expect(fractional.registeredAt == tenOnTheSecondOfOctober2026.addingTimeInterval(0.25))
    }
}
