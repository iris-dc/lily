import Foundation
import Testing
@testable import lily

/// The wizard shell across the group and tournament kinds: their walks, gating, dirty rule, submit and logged lines,
/// over the same harness as the event suite (`CreationWizardHarness`).
@MainActor
struct CreationWizardModelKindsTests {
    private typealias Harness = CreationWizardHarness
    private static let group = EventGroupRef(id: "group-1", name: "Mitte Kickers", visibility: .private, isDeleted: false)

    @Test func enteringGroupWalksItsOwnPages() {
        let harness = Harness()

        harness.model.enter(.group)

        #expect(harness.model.kind == .group && harness.model.groupModel != nil && harness.model.eventModel == nil)
        #expect(harness.model.path == [.group(.name)], "the kind page stays the root")
        #expect(harness.model.steps == [.group(.name), .group(.description), .group(.type), .group(.visibility),
                                        .group(.place), .group(.permissions)])
        #expect(harness.logger.count(in: .ui, mentioning: "begun", "group") == 1)
    }

    /// The tournament walk is decided by the opening like the event's: the hosting-group page exists exactly when
    /// the attempt may choose, and the seed's locked group reaches the tournament factory.
    @Test func theTournamentWalkFollowsTheOpening() {
        let offered = Harness(seed: CreationSeed(kind: .tournament))
        #expect(offered.model.tournamentModel != nil && offered.model.eventModel == nil)
        #expect(offered.model.steps.contains(.tournament(.group)))
        #expect(offered.logger.count(in: .ui, mentioning: "begun", "tournament") == 1)

        let locked = Harness(seed: CreationSeed(kind: .tournament, lockedGroup: Self.group), lockedGroup: Self.group)
        #expect(locked.factoryLockedGroups.values == [Self.group])
        #expect(locked.tournamentViewModel.lockedGroup == Self.group)
        #expect(!locked.model.steps.contains(.tournament(.group)), "a locked seed walks no hosting-group page")

        let groupless = Harness(seed: CreationSeed(kind: .tournament), hasEligibleGroups: false)
        #expect(!groupless.model.steps.contains(.tournament(.group)))
    }

    @Test func groupAdvanceGatesOnTheOwningStepAndLogsTheRefusal() {
        let harness = Harness(seed: CreationSeed(kind: .group))

        harness.model.advance(from: .group(.name))
        #expect(harness.model.path.isEmpty)
        #expect(harness.logger.count(in: .ui, at: .debug, mentioning: "refused Next", "nameTooShort") == 1)

        harness.groupViewModel.draft.name = "Kreuzberg Kickers"
        #expect(harness.model.allowsNext(from: .group(.name)), "the place issue belongs to the place step")
        harness.model.advance(from: .group(.name))
        #expect(harness.model.path == [.group(.description)])
    }

    /// Prepare's own write (the proposed spot) never dirties a group draft; the user's map pick does — the dirty
    /// rule reads every kind's place bookkeeping the same way.
    @Test func aGroupPreparesProposalIsNotAnEditButAMapPickIs() async {
        let harness = Harness(seed: CreationSeed(kind: .group),
                              locationService: MockLocationService(coordinate: AppConfig.Location.mockCenter))

        await harness.model.prepare()
        harness.model.noteDraftChanged()
        #expect(!harness.model.isDirty)

        harness.groupViewModel.draft.pickSpot(Coordinate(latitude: 54.352, longitude: 18.6466))
        harness.model.noteDraftChanged()
        #expect(harness.model.isDirty)
    }

    @Test func submittingAGroupCreatesOnceAndSignalsDone() async {
        let harness = Harness(seed: CreationSeed(kind: .group))
        harness.groupViewModel.draft.name = "Kreuzberg Kickers"
        harness.groupViewModel.draft.locationName = "Görlitzer Park"
        harness.groupViewModel.draft.coordinate = AppConfig.Location.mockCenter

        await harness.model.submit()

        #expect(harness.events.groupRepository.createdDrafts.count == 1)
        #expect(harness.model.isDone && !harness.model.isSubmitting)
        #expect(harness.logger.count(in: .ui, mentioning: "submitted", "group") == 1)
    }
}
