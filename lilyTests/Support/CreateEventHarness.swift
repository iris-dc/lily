import Foundation
@testable import lily

/// What a create view model handed on through `onCreated`.
@MainActor
final class CreatedEvents {
    private(set) var events: [SportEvent] = []

    func record(_ event: SportEvent) {
        events.append(event)
    }
}

/// A `CreateEventViewModel` over fakes with a fixed clock; `created` records what it handed on. Collaborators not
/// given are created in the body: a main-actor default argument would be evaluated off the actor.
@MainActor
final class CreateEventHarness {
    /// 08:25:07 UTC, so "the next full hour" is unambiguous. `nonisolated`: read by `@Test(arguments:)` off the actor.
    nonisolated static let now = Date(timeIntervalSince1970: 1_800_000_000 + 25 * 60 + 7)

    let repository = FakeEventRepository()
    let groupRepository = FakeGroupRepository()
    /// The caller is the user the fake makes host of every created game.
    let identity = FakeIdentityProvider()
    let logger = SpyLogger()
    let errorCenter: ErrorCenter
    let groups: MyGroupsStore
    let viewModel: CreateEventViewModel
    private let createdEvents = CreatedEvents()

    var created: [SportEvent] { createdEvents.events }

    init(locationService: (any LocationService)? = nil,
         lockedGroup: EventGroupRef? = nil,
         currencyCode: String = EventDraft.testCurrencyCode) {
        errorCenter = ErrorCenter(logger: logger)
        identity.currentUserID = repository.hostUserID
        groups = MyGroupsStore(repository: groupRepository,
                               identity: identity,
                               changes: ChangeTracker(),
                               errorCenter: errorCenter,
                               logger: logger)
        viewModel = CreateEventViewModel(repository: repository,
                                         identity: identity,
                                         locationService: locationService ?? MockLocationService(),
                                         groups: groups,
                                         errorCenter: errorCenter,
                                         logger: logger,
                                         now: { Self.now },
                                         currencyCode: currencyCode,
                                         lockedGroup: lockedGroup,
                                         onCreated: createdEvents.record)
    }

    /// Fills in what a valid draft needs beyond the defaults.
    func completeDraft() {
        viewModel.draft.title = "Thursday five-a-side"
        viewModel.draft.locationName = "Test Park"
        viewModel.draft.coordinate = AppConfig.Location.mockCenter
    }

    /// Puts groups into the store the way the sign-in load does.
    func loadGroups(_ groups: [SportGroup]) async {
        groupRepository.result = .success(groups)
        await self.groups.reload()
    }
}
