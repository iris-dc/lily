import Testing
@testable import lily

struct SportGroupCaptionTests {
    @Test func namesMembersAndType() {
        let group = SportGroup.fixture(type: .football, memberCount: 34)
        #expect(group.caption() == "34 members · Football")
    }

    @Test func skipsAMissingTypeAndAppendsTheSuffix() {
        let group = SportGroup.fixture(type: nil, memberCount: 1)
        #expect(group.caption(suffix: "Joined") == "1 member · Joined")
    }
}
