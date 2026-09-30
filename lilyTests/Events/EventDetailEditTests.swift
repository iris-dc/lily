import Foundation
import Testing
@testable import lily

/// Who may edit from the detail, and how the edit sheet's answer reaches it. The main detail suite is at its file limit.
@MainActor
struct EventDetailEditTests {
    private let repository = FakeEventRepository()
    private let identity = FakeIdentityProvider(currentUserID: "host")
    private let logger = SpyLogger()
    private let changed = CreatedEvents()

    private func makeViewModel(for event: SportEvent) -> EventDetailViewModel {
        EventDetailViewModel(event: event,
                             repository: repository,
                             identity: identity,
                             errorCenter: ErrorCenter(logger: logger),
                             recorder: SpyInteractionRecorder(),
                             logger: logger,
                             tryAgainDelay: .zero,
                             onChange: changed.record)
    }

    @Test func onlyTheHostMayEdit() {
        let hosted = SportEvent.fixture(hostUserId: "host", isJoined: true)
        let joined = SportEvent.fixture(hostUserId: "someone", isJoined: true)

        #expect(makeViewModel(for: hosted).canEdit)
        #expect(!makeViewModel(for: joined).canEdit)
        identity.currentUserID = nil
        #expect(!makeViewModel(for: hosted).canEdit, "a guest is nobody's host")
    }

    @Test func acceptReplacesTheEventAndTellsTheList() {
        let event = SportEvent.fixture(title: "Old", hostUserId: "host", isJoined: true)
        let viewModel = makeViewModel(for: event)
        let edited = event.updating(with: { var draft = EventDraft(editing: event); draft.title = "New"; return draft }())

        viewModel.accept(edited)

        #expect(viewModel.event.title == "New")
        #expect(changed.events == [edited])
    }
}
