import Foundation
import Testing
@testable import lily

struct ChatTimelineTests {
    private static let noon = Date(timeIntervalSince1970: 1_800_014_400)
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func message(_ id: String,
                         from sender: String = "u-2",
                         name: String = "Marta",
                         after offset: TimeInterval,
                         kind: MessageKind = .text,
                         clientMessageID: String? = nil) -> ChatMessage {
        .fixture(id: id,
                 senderUserID: sender,
                 senderName: name,
                 kind: kind,
                 eventID: "e",
                 clientMessageID: clientMessageID,
                 sentAt: Self.noon.addingTimeInterval(offset))
    }

    private func rows(_ messages: [ChatMessage],
                      pending: [PendingMessage] = [],
                      blocked: Set<String> = [],
                      members: [GroupMember] = []) -> [ChatRow] {
        ChatTimeline.rows(ChatTimeline.Input(messages: messages,
                                             pending: pending,
                                             blockedUserIDs: blocked,
                                             members: members,
                                             currentUserID: "u-1",
                                             calendar: Self.calendar))
    }

    /// One sender within the grouping window is one run: the name on the first bubble, the time under the last.
    @Test func runsGroupOneSenderWithinTheWindow() throws {
        let rows = rows([message("m1", after: 0), message("m2", after: 60), message("m3", after: 120),
                         message("m4", from: "u-1", name: "Me", after: 180), message("m5", after: 240)])

        let messageRows = rows.compactMap { if case .message(let row) = $0 { row } else { nil } }
        #expect(messageRows.map(\.isFirstInRun) == [true, false, false, true, true])
        #expect(messageRows.map(\.isLastInRun) == [false, false, true, true, true])
        #expect(messageRows.map(\.isOwn) == [false, false, false, true, false])
        #expect(rows.first.map { if case .day = $0 { true } else { false } } == true, "the first message opens a day")
    }

    @Test func aGapLongerThanTheWindowStartsANewRun() {
        let rows = rows([message("m1", after: 0), message("m2", after: AppConfig.Chat.groupingWindow)])

        let firsts = rows.compactMap { if case .message(let row) = $0 { row.isFirstInRun } else { nil } }
        #expect(firsts == [true, true])
    }

    @Test func dayDividersSeparateDays() {
        let rows = rows([message("m1", after: 0), message("m2", after: 60), message("m3", after: 86_400)])

        let days = rows.compactMap { if case .day(let date) = $0 { date } else { nil } }
        #expect(days.count == 2)
        #expect(days.map { Self.calendar.component(.day, from: $0) } == [15, 16])
        let runStarts = rows.compactMap { if case .message(let row) = $0 { row.isFirstInRun } else { nil } }
        #expect(runStarts == [true, false, true], "a divider breaks the run")
    }

    @Test func systemRowsAreCentredAndBreakRuns() {
        let rows = rows([message("m1", after: 0), message("m2", after: 10, kind: .eventCreated), message("m3", after: 20)])

        #expect(rows.count == 4)
        guard case .system(let system) = rows[2] else { Issue.record("expected a system row"); return }
        #expect(system.eventId == "e" && system.kind == .eventCreated)
        let runStarts = rows.compactMap { if case .message(let row) = $0 { row.isFirstInRun } else { nil } }
        #expect(runStarts == [true, true])
    }

    @Test func tombstonesStayInPlace() {
        let rows = rows([message("m1", after: 0).markingDeleted(), message("m2", after: 10)])

        let deleted = rows.compactMap { if case .message(let row) = $0 { row.message.isDeleted } else { nil } }
        #expect(deleted == [true, false])
    }

    @Test func blockedSendersAreHidden() {
        let rows = rows([message("m1", from: "u-9", name: "Troll", after: 0), message("m2", after: 10)], blocked: ["u-9"])

        #expect(rows.compactMap { if case .message(let row) = $0 { row.message.id } else { nil } } == ["m2"])
    }

    /// The roster's name wins while the sender is a member; the snapshot stays for one who left.
    @Test func liveNamesComeFromTheRoster() {
        let members = [GroupMember(userId: "u-2", displayName: "Marta B.", role: .member, joinedAt: Self.noon)]
        let rows = rows([message("m1", after: 0), message("m2", from: "u-3", name: "Jonas", after: 600)], members: members)

        let names = rows.compactMap { if case .message(let row) = $0 { row.senderName } else { nil } }
        #expect(names == ["Marta B.", "Jonas"])
    }

    @Test func pendingMessagesComeLastAndKeepTheirClientIds() {
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = "on my way"
        let pending = PendingMessage(draft: draft, sentAt: Self.noon)

        let rows = rows([message("m1", after: 0)], pending: [pending])

        #expect(rows.last?.id == "c-1")
        guard case .pending(let row) = rows.last else { Issue.record("expected a pending row"); return }
        #expect(row.text == "on my way" && !row.hasFailed)
    }

    /// The caller's newest message runs on into their unsent one as it will once that is stored, so the confirmation
    /// moves the time to the new bubble and changes no row's height.
    @Test func theCallersNewestMessageRunsOnIntoTheirUnsentOne() {
        let unsent = PendingMessage(draft: MessageDraft(clientMessageID: "c-1"), sentAt: Self.noon.addingTimeInterval(60))
        let mine = message("m1", from: "u-1", name: "Me", after: 0)

        let rows = rows([mine], pending: [unsent])

        guard case .message(let row) = rows[1] else { Issue.record("expected my message"); return }
        #expect(!row.isLastInRun)
        let stored = message("m2", from: "u-1", name: "Me", after: 60, clientMessageID: "c-1")
        let confirmed = self.rows([mine, stored]).compactMap { if case .message(let row) = $0 { row.isLastInRun } else { nil } }
        #expect(confirmed == [false, true], "the same runs once the bubble is stored")
    }

    @Test func anotherSendersMessageOrAGapEndsTheRunBeforeTheUnsentOne() {
        let unsent = PendingMessage(draft: MessageDraft(clientMessageID: "c-1"),
                                    sentAt: Self.noon.addingTimeInterval(AppConfig.Chat.groupingWindow + 60))
        let lasts = rows([message("m1", after: 0), message("m2", from: "u-1", name: "Me", after: 60)], pending: [unsent])
            .compactMap { if case .message(let row) = $0 { row.isLastInRun } else { nil } }
        #expect(lasts == [true, true])

        let soon = PendingMessage(draft: MessageDraft(clientMessageID: "c-2"), sentAt: Self.noon.addingTimeInterval(30))
        let marta = rows([message("m1", after: 0)], pending: [soon])
            .compactMap { if case .message(let row) = $0 { row.isLastInRun } else { nil } }
        #expect(marta == [true], "Marta's run ends where my unsent message starts")
    }

    /// A failed bubble shows its hint, not a time, so the message before it keeps its own.
    @Test func aFailedUnsentMessageLeavesTheCallersRunEnded() {
        var failed = PendingMessage(draft: MessageDraft(clientMessageID: "c-1"), sentAt: Self.noon.addingTimeInterval(60))
        failed.state = .failed

        let rows = rows([message("m1", from: "u-1", name: "Me", after: 0)], pending: [failed])

        guard case .message(let row) = rows[1] else { Issue.record("expected my message"); return }
        #expect(row.isLastInRun)
    }

    @Test func rowIdsAreStable() {
        let rows = rows([message("m1", after: 0)])
        #expect(rows.map(\.id) == ["day-1799971200", "m1"], "the day's id is its UTC midnight")
    }

    /// The stored message takes over the unsent bubble's row, so the transcript animates nothing at the confirmation.
    @Test func aStoredMessageKeepsTheIdOfTheBubbleItReplaces() {
        let rows = rows([message("m1", from: "u-1", after: 0, clientMessageID: "c-1")])
        #expect(rows.map(\.id) == ["day-1799971200", "c-1"])
        #expect(rows.last?.messageID == "m1", "a quote still finds the row by the stored id")
    }

    @Test func aBubbleWhoseMessageIsAlreadyHeldIsLeftOut() {
        let unsent = PendingMessage(draft: MessageDraft(clientMessageID: "c-1"), sentAt: Self.noon)
        let other = PendingMessage(draft: MessageDraft(clientMessageID: "c-2"), sentAt: Self.noon)

        let rows = rows([message("m1", from: "u-1", after: 0, clientMessageID: "c-1")], pending: [unsent, other])

        #expect(rows.map(\.id) == ["day-1799971200", "c-1", "c-2"], "the landed bubble is gone, the other stays")
        guard case .message = rows[1] else { Issue.record("expected the stored message"); return }
    }

    /// The follow rule reads whose a row is: the caller's unsent and sent messages are theirs, a chip or a note nobody's.
    @Test func rowsKnowWhoseTheyAre() {
        let unsent = PendingMessage(draft: MessageDraft(clientMessageID: "c-1"), sentAt: Self.noon)
        let rows = rows([message("m1", after: 0), message("m2", from: "u-1", name: "Me", after: 10),
                         message("m3", after: 20, kind: .eventCreated)], pending: [unsent])

        #expect(rows.map(\.isOwn) == [false, false, true, false, true], "the day, Marta's, mine, the note, my unsent one")
    }
}
