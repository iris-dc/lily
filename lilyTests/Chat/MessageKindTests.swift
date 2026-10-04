import Foundation
import Testing
@testable import lily

/// The message kind on the wire: the known names round-trip, an unknown one is kept by name and re-encoded as it came,
/// and a row of such a kind is a system note the transcript leaves out, so a room from a newer backend still decodes.
struct MessageKindTests {
    private static let noon = Date(timeIntervalSince1970: 1_800_014_400)
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    @Test func knownKindsRoundTripThroughTheirWireNames() throws {
        #expect(MessageKind(wireName: "text") == .text && MessageKind(wireName: "event_created") == .eventCreated)
        #expect(MessageKind.text.wireName == "text" && MessageKind.eventCreated.wireName == "event_created")
        #expect(!MessageKind.text.isUnknown && !MessageKind.eventCreated.isUnknown)

        let json = try #require(String(bytes: try JSONEncoder().encode([MessageKind.text, .eventCreated]), encoding: .utf8))
        #expect(json == #"["text","event_created"]"#)
        #expect(try JSONDecoder().decode([MessageKind].self, from: Data(json.utf8)) == [.text, .eventCreated])
    }

    @Test func anUnknownKindDecodesByNameAndEncodesAsItCame() throws {
        let decoded = try JSONDecoder().decode([MessageKind].self, from: Data(#"["x"]"#.utf8))

        #expect(decoded == [.unknown("x")] && decoded[0].isUnknown && decoded[0].wireName == "x")
        #expect(String(bytes: try JSONEncoder().encode(decoded), encoding: .utf8) == #"["x"]"#)
    }

    /// A message of a kind a newer backend sends decodes with every other field intact, counts as a system note and
    /// goes back out with the same kind.
    @Test func aMessageOfAnUnknownKindDecodesAsASystemNote() throws {
        let sample = ContractSamples.systemMessage.replacingOccurrences(of: "event_created", with: "tournament_started")
        try #require(sample != ContractSamples.systemMessage)

        let message = try ContractSamples.decode(ChatMessage.self, from: sample)

        #expect(message.kind == .unknown("tournament_started") && message.isSystem)
        #expect(message.id == "01J8ZK7Q9X2M4N6P8R0T2V4W6Z" && message.senderName == "Marta" && message.eventId == "evt_01J")
        let json = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(message), encoding: .utf8))
        #expect(json.contains(#""kind":"tournament_started""#))
        #expect(try ContractSamples.decode(ChatMessage.self, from: json) == message)
    }

    /// The transcript shows nothing for a kind it does not know: no row, no day chip for it alone, and the run around it
    /// is judged as if it were not there.
    @Test func theTimelineDropsRowsOfAnUnknownKind() {
        let unknown = message("m2", after: 10, kind: .unknown("tournament_started"))

        let rows = rows([message("m1", after: 0), unknown, message("m3", after: 20)])

        #expect(rows.count == 3, "a day chip and the two text messages")
        #expect(!rows.contains { if case .system = $0 { true } else { false } })
        let messageRows = rows.compactMap { if case .message(let row) = $0 { row } else { nil } }
        #expect(messageRows.map(\.message.id) == ["m1", "m3"])
        #expect(messageRows.map(\.isFirstInRun) == [true, false], "the dropped row does not break the run")
        #expect(self.rows([unknown]).isEmpty)
        #expect(self.rows([message("m1", after: 0, kind: .eventCreated)]).count == 2, "a known system note stays")
    }

    private func message(_ id: String, after offset: TimeInterval, kind: MessageKind = .text) -> ChatMessage {
        .fixture(id: id, kind: kind, eventID: "e", sentAt: Self.noon.addingTimeInterval(offset))
    }

    private func rows(_ messages: [ChatMessage]) -> [ChatRow] {
        ChatTimeline.rows(ChatTimeline.Input(messages: messages, currentUserID: "u-1", calendar: Self.calendar))
    }
}
