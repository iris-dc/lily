import Foundation
import Testing

/// `makeTestDefaults()` hands every store and composition root a `TestDefaults`: a `UserDefaults` suite of its own,
/// whose values go with the last reference, so no two tests share a stored session and a run leaves no stored
/// session, choice or filter in the simulator's container.
@MainActor
struct TestDefaultsTests {
    private let key = "k"

    @Test func aReleasedTestSuiteLeavesNothingBehind() throws {
        var defaults: TestDefaults? = TestDefaults(id: UUID())
        let name = try #require(defaults?.suiteName)
        defaults?.set("kept", forKey: key)

        defaults = nil

        #expect(UserDefaults(suiteName: name)?.string(forKey: key) == nil)
    }

    /// The removal is tied to the release, not to construction: another reader of the suite sees the value while the
    /// instance lives.
    @Test func aHeldTestSuiteKeepsItsValuesForAnotherReader() throws {
        let defaults = try #require(TestDefaults(id: UUID()))
        defaults.set("kept", forKey: key)

        let read = withExtendedLifetime(defaults) { UserDefaults(suiteName: defaults.suiteName)?.string(forKey: key) }

        #expect(read == "kept")
    }

    @Test func everyMakeTestDefaultsIsASuiteOfItsOwn() throws {
        let first = try #require(makeTestDefaults() as? TestDefaults)
        let second = try #require(makeTestDefaults() as? TestDefaults)
        first.set("kept", forKey: key)

        #expect(first.suiteName != second.suiteName)
        #expect(second.string(forKey: key) == nil)
    }
}
