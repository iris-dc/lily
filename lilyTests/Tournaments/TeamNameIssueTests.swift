import Foundation
import Testing
@testable import lily

/// A team's name against the backend's limits (`AppConfig.Tournaments.teamNameLength`, 2...40 UTF-16 units), so a
/// name the sheet lets through never earns a 400.
struct TeamNameIssueTests {
    private static let limits = AppConfig.Tournaments.teamNameLength

    @Test func aNameShorterThanTwoUnitsIsTooShort() {
        #expect(TeamNameIssue.issue(in: "") == .tooShort)
        #expect(TeamNameIssue.issue(in: "a") == .tooShort)
    }

    @Test func whitespaceAroundTheNameDoesNotCount() {
        #expect(TeamNameIssue.issue(in: "  ab  ") == nil)
        #expect(TeamNameIssue.issue(in: "  a  ") == .tooShort)
    }

    @Test func aNameOverFortyUnitsIsTooLong() {
        #expect(TeamNameIssue.issue(in: String(repeating: "a", count: Self.limits.upperBound)) == nil)
        #expect(TeamNameIssue.issue(in: String(repeating: "a", count: Self.limits.upperBound + 1)) == .tooLong)
    }

    /// An emoji is one character and two UTF-16 units, which is how Java's `String.length()` counts it.
    @Test func lengthCountsUTF16UnitsLikeTheBackend() {
        let half = Self.limits.upperBound / 2
        #expect(TeamNameIssue.issue(in: String(repeating: "😀", count: half)) == nil)
        #expect(TeamNameIssue.issue(in: String(repeating: "😀", count: half + 1)) == .tooLong)
    }
}
