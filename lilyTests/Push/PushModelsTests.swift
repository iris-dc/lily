import Foundation
import Testing
@testable import lily

struct PushModelsTests {
    @Test func eventIDIsReadFromAReminderPayloadOnly() {
        #expect(PushPayload.eventID(from: ["kind": "event_reminder", "eventId": "e1"]) == "e1")
        #expect(PushPayload.eventID(from: ["kind": "group_invite", "eventId": "e1"]) == nil)
        #expect(PushPayload.eventID(from: ["kind": "event_reminder", "eventId": ""]) == nil)
        #expect(PushPayload.eventID(from: ["kind": "event_reminder"]) == nil)
        #expect(PushPayload.eventID(from: ["aps": ["alert": "x"]]) == nil)
    }

    @Test func aRegistrationIsCurrentForTheSameTokenAndUserWithinTheInterval() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let registration = LastDeviceRegistration(token: "t", userID: "u", registeredAt: now)

        #expect(registration.isCurrent(token: "t", userID: "u", now: now.addingTimeInterval(3_599), within: 3_600))
        #expect(!registration.isCurrent(token: "t", userID: "u", now: now.addingTimeInterval(3_600), within: 3_600))
        #expect(!registration.isCurrent(token: "other", userID: "u", now: now, within: 3_600))
        #expect(!registration.isCurrent(token: "t", userID: "someone", now: now, within: 3_600))
    }

    @Test func theCurrentEnvironmentFollowsTheBuildAndTheWireNamesAreLowerCase() throws {
        #if DEBUG
        #expect(PushEnvironment.current == .sandbox)
        #else
        #expect(PushEnvironment.current == .production)
        #endif
        let payload = DeviceRegistrationPayload(token: "ab", platform: "ios", environment: .sandbox, appVersion: "1.0 (42)")
        let json = try #require(String(data: JSONEncoder().encode(payload), encoding: .utf8))
        #expect(json.contains("\"environment\":\"sandbox\"") && json.contains("\"platform\":\"ios\""))
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
