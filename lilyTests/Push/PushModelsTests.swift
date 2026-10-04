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

    @Test func aRegistrationStoredBeforeTheAppSpokeLanguagesReadsWithoutOneAndIsNotCurrent() throws {
        let stored = try JSONDecoder.apiDecoder.decode(LastDeviceRegistration.self, from: Data("""
        {"token":"t","userID":"u","registeredAt":"2026-10-02T10:00:00Z"}
        """.utf8))
        #expect(stored.locale == nil)
        #expect(!stored.isCurrent(token: "t", userID: "u", locale: "en", now: stored.registeredAt, within: 3_600))
    }

    @Test func theCurrentEnvironmentFollowsTheBuildAndTheWireNamesAreLowerCase() throws {
        #if DEBUG
        #expect(PushEnvironment.current == .sandbox)
        #else
        #expect(PushEnvironment.current == .production)
        #endif
        let payload = DeviceRegistrationPayload(token: "ab",
                                                platform: "ios",
                                                environment: .sandbox,
                                                appVersion: "1.0 (42)",
                                                locale: "ru")
        let json = try #require(String(data: JSONEncoder().encode(payload), encoding: .utf8))
        #expect(json.contains("\"environment\":\"sandbox\"") && json.contains("\"platform\":\"ios\""))
        #expect(json.contains("\"locale\":\"ru\""))
        let registration = try JSONDecoder.apiDecoder.decode(DeviceRegistration.self, from: Data("""
        {"token":"ab","environment":"production","registeredAt":"2026-10-02T10:00:00Z"}
        """.utf8))
        #expect(registration.environment == .production && registration.token == "ab")
    }
}

private extension JSONDecoder {
    /// The backend's instant format, as `APIJSONCoding` reads it.
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
