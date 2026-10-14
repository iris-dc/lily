import Foundation
import Testing
@testable import lily

/// How a scope reads its query: the backend treats a blank one as no query and trims the rest, so both repositories
/// read `searchPrefix` rather than the raw text.
@MainActor
struct GroupScopeTests {
    @Test func aBlankOrPaddedQueryHasNoSearchPrefix() {
        #expect(GroupScope.discover(query: nil, type: nil).searchPrefix == nil)
        #expect(GroupScope.discover(query: "", type: nil).searchPrefix == nil)
        #expect(GroupScope.discover(query: "  \n", type: nil).searchPrefix == nil)
    }

    @Test func aTypedQueryIsTrimmedToItsPrefix() {
        #expect(GroupScope.discover(query: " ber ", type: .football).searchPrefix == "ber")
    }

    @Test func mineHasNoSearchPrefix() {
        #expect(GroupScope.mine.searchPrefix == nil)
    }
}
