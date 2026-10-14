import Testing
@testable import lily

/// The fragment vocabulary tests pin log lines with: every part must sit in one line, the level narrows, no part means
/// every line, and another category never answers.
@MainActor
struct SpyLoggerTests {
    private let logger = SpyLogger()

    init() {
        logger.log(.info, .events, "Event e1 updated")
        logger.log(.info, .events, "Joined e1")
        logger.log(.warning, .events, "Event e2 updated")
    }

    @Test func everyPartMustAppearInOneLine() {
        #expect(logger.lines(in: .events, mentioning: "Event", "e1") == ["Event e1 updated"])
        #expect(!logger.hasLine(in: .events, mentioning: "Joined", "updated"), "the parts sit in two different lines")
    }

    @Test func countFollowsTheLevelAndNoPartsMeansEveryLine() {
        #expect(logger.count(in: .events) == 3)
        #expect(logger.count(in: .events, at: .info) == 2)
        #expect(logger.count(in: .events, at: .warning, mentioning: "e1") == 0)
    }

    @Test func anotherCategoryNeverMatches() {
        #expect(!logger.hasLine(in: .chat, mentioning: "e1"))
        #expect(logger.count(in: .chat) == 0)
    }

    @Test func theArrayHelperTakesPartsListedOrAsAnArray() {
        let lines = ["Event e1 updated", "Joined e1"]
        #expect(lines.mentioning("e1") == lines)
        #expect(lines.mentioning(["Event", "e1"]) == ["Event e1 updated"])
        #expect(lines.mentioning().count == 2, "no part answers every line")
    }
}
