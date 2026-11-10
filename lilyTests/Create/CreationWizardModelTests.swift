import Foundation
import Testing
@testable import lily

/// The wizard shell over a real event view model on fakes: the one-way kind, the lazy factory, prepare on kind
/// entry, the user-edit dirty rule, the gating walk, the submit lock and the logged lines (pinned by count plus
/// fragment).
@MainActor
struct CreationWizardModelTests {
    nonisolated private static let everythingOn = CreationWizardPolicy.Flags(groups: true, tournaments: true)
    private static let group = EventGroupRef(id: "group-1", name: "Mitte Kickers", visibility: .private, isDeleted: false)

    @MainActor
    private final class Harness {
        let events: CreateEventHarness
        let logger: SpyLogger
        /// The locked group each factory call carried, recording that the factory ran at all.
        let factoryLockedGroups: Recorded<EventGroupRef?>
        let model: CreationWizardModel<CreateEventViewModel>

        init(seed: CreationSeed = .empty,
             flags: CreationWizardPolicy.Flags = CreationWizardModelTests.everythingOn,
             hasEligibleGroups: Bool = true,
             locationService: (any LocationService)? = nil,
             lockedGroup: EventGroupRef? = nil) {
            let events = CreateEventHarness(locationService: locationService, lockedGroup: lockedGroup)
            let logger = SpyLogger()
            let recorded = Recorded<EventGroupRef?>()
            self.events = events
            self.logger = logger
            factoryLockedGroups = recorded
            let factories = CreationWizardFactories(event: { locked in
                recorded.record(locked)
                return events.viewModel
            })
            let opening = CreationWizardPolicy.opening(for: seed, flags: flags, hasEligibleGroups: hasEligibleGroups)
            model = CreationWizardModel(opening: opening, factories: factories, logger: logger)
        }

        var viewModel: CreateEventViewModel { events.viewModel }
    }

    @Test func theKindIsEnteredOnceAndTheViewModelMadeLazily() {
        let harness = Harness()
        #expect(harness.model.kind == nil && harness.model.eventModel == nil)
        #expect(harness.factoryLockedGroups.values.isEmpty && harness.model.path.isEmpty)

        harness.model.enter(.event)
        #expect(harness.model.kind == .event && harness.model.eventModel != nil)
        #expect(harness.factoryLockedGroups.values.count == 1)
        #expect(harness.model.path == [.event(.name)])
        #expect(harness.logger.count(in: .ui, mentioning: "begun", "event") == 1)

        harness.model.enter(.group)
        #expect(harness.model.kind == .event)
        #expect(harness.factoryLockedGroups.values.count == 1 && harness.model.path == [.event(.name)])
        #expect(harness.logger.count(in: .ui, mentioning: "begun") == 1)
    }

    /// Group and tournament pages land in slice 3; until then the wizard refuses the kind instead of locking onto it.
    @Test func aKindWhosePagesHaveNotLandedIsRefusedBeforeTheKindIsFixed() {
        let harness = Harness()

        harness.model.enter(.tournament)

        #expect(harness.model.kind == nil && harness.model.path.isEmpty)
        #expect(harness.factoryLockedGroups.values.isEmpty)
        #expect(harness.logger.count(in: .ui, at: .warning, mentioning: "no pages", "tournament") == 1)
    }

    @Test func aSeededKindEntersAtInitAndTheFirstStepIsTheRoot() {
        let harness = Harness(seed: CreationSeed(kind: .event),
                              flags: CreationWizardPolicy.Flags(groups: false, tournaments: false))

        #expect(!harness.model.opening.showsKindPage)
        #expect(harness.model.kind == .event && harness.model.eventModel != nil)
        #expect(harness.model.path.isEmpty, "the first step is the stack root, never a path entry")
        #expect(harness.model.steps == [.event(.name), .event(.type), .event(.when),
                                        .event(.place), .event(.players), .event(.details)],
                "flags without groups walk no hosting-group page")
        #expect(harness.logger.count(in: .ui, mentioning: "begun", "event") == 1)
    }

    @Test func theSeedsLockedGroupReachesTheEventFactory() {
        let harness = Harness(seed: CreationSeed(kind: .event, lockedGroup: Self.group), lockedGroup: Self.group)

        #expect(harness.factoryLockedGroups.values == [Self.group])
        #expect(harness.viewModel.lockedGroup == Self.group)
        #expect(!harness.model.steps.contains(.event(.group)), "a locked seed walks no hosting-group page")
    }

    /// The hosting-group page is on the walk exactly when groups are on, the seed locks nothing and a group was
    /// there to host in; the walk is decided at the opening, so the eligible-groups reload can never change it
    /// mid-attempt.
    @Test func theGroupStepFollowsTheOpening() {
        let offered = Harness(seed: CreationSeed(kind: .event))
        #expect(offered.model.steps.contains(.event(.group)))

        let flagless = Harness(seed: CreationSeed(kind: .event),
                               flags: CreationWizardPolicy.Flags(groups: false, tournaments: true))
        #expect(!flagless.model.steps.contains(.event(.group)))

        let groupless = Harness(seed: CreationSeed(kind: .event), hasEligibleGroups: false)
        #expect(!groupless.model.steps.contains(.event(.group)), "no group to host in walks no hosting-group page")
    }

    @Test func prepareRunsTheEnteredKindsPrepareOnce() async {
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let harness = Harness(seed: CreationSeed(kind: .event), locationService: service)

        await harness.model.prepare()
        await harness.model.prepare()

        #expect(service.callCount == 1)
        #expect(harness.viewModel.draft.coordinate == AppConfig.Location.mockCenter)
    }

    /// Dirty is the user's edit, judged against the draft as made, not a post-prepare snapshot: an edit while
    /// prepare is still awaiting its position must count.
    @Test func anEditDuringAHeldPrepareCountsAsDirty() async {
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        service.holdsRequests = true
        let harness = Harness(seed: CreationSeed(kind: .event), locationService: service)

        let prepare = Task { await harness.model.prepare() }
        await settle(until: { service.isHolding })
        harness.model.noteDraftChanged()
        #expect(!harness.model.isDirty, "nothing edited yet")

        harness.viewModel.draft.title = "Padel after work"
        harness.model.noteDraftChanged()
        #expect(harness.model.isDirty)

        service.releaseRequests()
        await prepare.value
        #expect(harness.model.isDirty, "the flag stays latched")
    }

    /// Prepare's own write (the proposed spot) never dirties the draft; the user's map pick does.
    @Test func preparesProposalIsNotAnEditButAMapPickIs() async {
        let harness = Harness(seed: CreationSeed(kind: .event),
                              locationService: MockLocationService(coordinate: AppConfig.Location.mockCenter))

        await harness.model.prepare()
        harness.model.noteDraftChanged()
        #expect(!harness.model.isDirty)

        harness.viewModel.draft.pickSpot(Coordinate(latitude: 54.352, longitude: 18.6466))
        harness.model.noteDraftChanged()
        #expect(harness.model.isDirty)
    }

    @Test func advanceMovesForwardOnlyWhenTheStepOwnsNoLiveIssue() {
        let harness = Harness(seed: CreationSeed(kind: .event))

        harness.model.advance(from: .event(.name))
        #expect(harness.model.path.isEmpty)
        #expect(!harness.model.allowsNext(from: .event(.name)))
        #expect(harness.logger.count(in: .ui, at: .debug, mentioning: "refused Next", "titleMissing") == 1)

        harness.viewModel.draft.title = "Thursday five-a-side"
        #expect(harness.model.allowsNext(from: .event(.name)), "the place issue belongs to the place step")
        harness.model.advance(from: .event(.name))
        #expect(harness.model.path == [.event(.type)])
    }

    /// Only the entry on top advances: a double-tapped Next pushes once, and a tap gone stale across a pop neither
    /// pushes nor skips a step — in both root shapes.
    @Test func advanceRunsOnlyFromTheStepOnTop() {
        let seeded = Harness(seed: CreationSeed(kind: .event))
        seeded.viewModel.draft.title = "Thursday five-a-side"
        seeded.model.advance(from: .event(.name))
        seeded.model.advance(from: .event(.name))
        #expect(seeded.model.path == [.event(.type)], "a double tap pushes once")

        seeded.model.pop(to: .event(.name))
        seeded.model.advance(from: .event(.type))
        #expect(seeded.model.path.isEmpty, "a stale tap from a popped step pushes nothing")

        let picked = Harness()
        picked.model.enter(.event)
        picked.viewModel.draft.title = "Thursday five-a-side"
        picked.model.advance(from: .event(.name))
        picked.model.advance(from: .event(.name))
        #expect(picked.model.path == [.event(.name), .event(.type)], "one push under the kind-page root too")
    }

    @Test func popReturnsToTheOwningStepInBothRootShapes() {
        let seeded = Harness(seed: CreationSeed(kind: .event))
        seeded.events.completeDraft()
        seeded.model.advance(from: .event(.name))
        seeded.model.advance(from: .event(.type))
        #expect(seeded.model.path == [.event(.type), .event(.when)])
        seeded.model.pop(to: .event(.name))
        #expect(seeded.model.path.isEmpty, "the first step is the root when the kind page is skipped")

        let picked = Harness()
        picked.model.enter(.event)
        picked.events.completeDraft()
        picked.model.advance(from: .event(.name))
        picked.model.pop(to: .event(.name))
        #expect(picked.model.path == [.event(.name)], "the kind page stays the root under a picked kind")
    }

    /// An issue that aged on an earlier step blocks the final gate; the hint names that step to pop back to.
    @Test func aStaleEarlierIssueBlocksTheFinalGateAndNamesItsStep() {
        let harness = Harness(seed: CreationSeed(kind: .event))
        harness.events.completeDraft()
        for step in harness.model.steps.dropLast() { harness.model.advance(from: step) }
        #expect(harness.model.path.last == .event(.details), "the walk reaches the final step")
        #expect(harness.model.blockedEarlierStep(before: .event(.details)) == nil)

        harness.viewModel.draft.title = " "

        #expect(!harness.model.canSubmit)
        #expect(harness.model.blockedEarlierStep(before: .event(.details)) == .event(.name))
        #expect(harness.model.firstBlockingIssue(on: .event(.name)) == .titleMissing)
    }

    @Test func submitLocksCreatesOnceAndSignalsDone() async {
        let harness = Harness(seed: CreationSeed(kind: .event))
        harness.events.completeDraft()
        harness.events.repository.holdsRequests = true

        let submit = Task { await harness.model.submit() }
        await settle(until: { harness.events.repository.isHolding })
        #expect(harness.model.isSubmitting && !harness.model.isDone)

        await harness.model.submit()
        harness.events.repository.releaseRequests()
        await submit.value

        #expect(harness.events.repository.createdDrafts.count == 1)
        #expect(harness.events.created.count == 1)
        #expect(harness.model.isDone && !harness.model.isSubmitting)
        #expect(harness.logger.count(in: .ui, mentioning: "submitted", "event") == 1)
    }

    @Test func closingWithoutCreatingLogsAbandonedOnce() {
        let harness = Harness()
        harness.model.enter(.event)

        harness.model.noteClosed()
        harness.model.noteClosed()

        #expect(harness.logger.count(in: .ui, mentioning: "abandoned", "event") == 1)
    }

    @Test func closingAfterTheCreateIsNotAnAbandonment() async {
        let harness = Harness(seed: CreationSeed(kind: .event))
        harness.events.completeDraft()

        await harness.model.submit()
        harness.model.noteClosed()

        #expect(harness.model.isDone)
        #expect(harness.logger.count(in: .ui, mentioning: "abandoned") == 0)
    }
}
