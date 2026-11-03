import Foundation
import Testing
@testable import lily

/// Who may edit from the detail, and how the edit sheet's answer reaches it.
@MainActor
struct EventDetailEditTests {
    @Test func onlyTheHostMayEdit() {
        let hosted = SportEvent.fixture(hostUserId: "host", isJoined: true)
        let joined = SportEvent.fixture(hostUserId: "someone", isJoined: true)

        #expect(EventDetailHarness(event: hosted, userID: "host").viewModel.canEdit)
        #expect(!EventDetailHarness(event: joined, userID: "host").viewModel.canEdit)
        #expect(!EventDetailHarness(event: hosted, userID: nil).viewModel.canEdit, "a guest is nobody's host")
    }

    @Test func acceptReplacesTheEventAndTellsTheList() {
        let event = SportEvent.fixture(title: "Old", hostUserId: "host", isJoined: true)
        let harness = EventDetailHarness(event: event, userID: "host")
        let edited = event.updating(with: { var draft = EventDraft(editing: event); draft.title = "New"; return draft }())

        harness.viewModel.accept(edited)

        #expect(harness.viewModel.event.title == "New")
        #expect(harness.replaced == [edited])
    }
}
