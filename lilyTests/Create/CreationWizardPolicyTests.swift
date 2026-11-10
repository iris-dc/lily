import Testing
@testable import lily

struct CreationWizardPolicyTests {
    // Not private: a `@Test(arguments:)` method's parameter type must be as visible as the method.
    typealias Flags = CreationWizardPolicy.Flags
    private typealias Opening = CreationWizardPolicy.Opening

    private static let everythingOn = Flags(groups: true, tournaments: true)
    private static let releaseFlags = Flags(groups: false, tournaments: false)
    private static let allFlags = [everythingOn, Flags(groups: true, tournaments: false),
                                   Flags(groups: false, tournaments: true), releaseFlags]
    private static let group = EventGroupRef(id: "group-1", name: "Mitte Kickers", visibility: .private, isDeleted: false)

    /// The matrix tests decide for a caller with a group to host in; the fact itself only rides through
    /// (`theEligibleGroupsFactRidesTheOpeningUntouched`) and gates nothing in the matrix.
    private static func opening(for seed: CreationSeed, flags: Flags) -> Opening {
        CreationWizardPolicy.opening(for: seed, flags: flags, hasEligibleGroups: true)
    }

    @Test func thePlusWithEverythingOnOpensTheKindPageWithAllThreeKinds() {
        let opening = Self.opening(for: .empty, flags: Self.everythingOn)
        #expect(opening == Opening(kindsOffered: [.event, .group, .tournament],
                                   showsKindPage: true,
                                   seed: .empty,
                                   flags: Self.everythingOn,
                                   hasEligibleGroups: true))
    }

    @Test func thePlusWithoutTournamentsOffersEventAndGroup() {
        let opening = Self.opening(for: .empty, flags: Flags(groups: true, tournaments: false))
        #expect(opening == Opening(kindsOffered: [.event, .group],
                                   showsKindPage: true,
                                   seed: .empty,
                                   flags: Flags(groups: true, tournaments: false),
                                   hasEligibleGroups: true))
    }

    @Test func thePlusWithoutGroupsOffersEventAndTournament() {
        let opening = Self.opening(for: .empty, flags: Flags(groups: false, tournaments: true))
        #expect(opening == Opening(kindsOffered: [.event, .tournament],
                                   showsKindPage: true,
                                   seed: .empty,
                                   flags: Flags(groups: false, tournaments: true),
                                   hasEligibleGroups: true))
    }

    @Test func theReleasePlusSkipsTheKindPageAndOpensTheEventFlow() {
        let opening = Self.opening(for: .empty, flags: Self.releaseFlags)
        #expect(opening == Opening(kindsOffered: [.event],
                                   showsKindPage: false,
                                   seed: CreationSeed(kind: .event),
                                   flags: Self.releaseFlags,
                                   hasEligibleGroups: true))
    }

    @Test(arguments: CreationWizardPolicyTests.allFlags)
    func aSeededEventOpensTheEventFlowUnderAnyFlags(flags: Flags) {
        let opening = Self.opening(for: CreationSeed(kind: .event), flags: flags)
        #expect(!opening.showsKindPage)
        #expect(opening.seed == CreationSeed(kind: .event))
        #expect(opening.kindsOffered == CreationWizardPolicy.kindsOffered(flags: flags))
    }

    @Test(arguments: [true, false])
    func aSeededGroupOpensTheGroupFlowWhileGroupsAreOn(tournaments: Bool) {
        let opening = Self.opening(for: CreationSeed(kind: .group),
                                   flags: Flags(groups: true, tournaments: tournaments))
        #expect(!opening.showsKindPage)
        #expect(opening.seed == CreationSeed(kind: .group))
    }

    @Test(arguments: [true, false])
    func aSeededTournamentOpensTheTournamentFlowWhileTournamentsAreOn(groups: Bool) {
        let opening = Self.opening(for: CreationSeed(kind: .tournament),
                                   flags: Flags(groups: groups, tournaments: true))
        #expect(!opening.showsKindPage)
        #expect(opening.seed == CreationSeed(kind: .tournament))
    }

    @Test func aGameFromAGroupKeepsItsLockedGroupAndSkipsTheKindPage() {
        let seed = CreationSeed(kind: .event, lockedGroup: Self.group)
        let opening = Self.opening(for: seed, flags: Self.everythingOn)
        #expect(opening == Opening(kindsOffered: [.event, .group, .tournament],
                                   showsKindPage: false,
                                   seed: seed,
                                   flags: Self.everythingOn,
                                   hasEligibleGroups: true))
    }

    @Test func aTournamentFromAGroupKeepsItsLockedGroupAndSkipsTheKindPage() {
        let seed = CreationSeed(kind: .tournament, lockedGroup: Self.group)
        let opening = Self.opening(for: seed, flags: Self.everythingOn)
        #expect(!opening.showsKindPage)
        #expect(opening.seed == seed)
    }

    @Test func aSeededKindTheFlagsDoNotOfferFallsBackToTheKindPage() {
        let opening = Self.opening(for: CreationSeed(kind: .tournament),
                                   flags: Flags(groups: true, tournaments: false))
        #expect(opening == Opening(kindsOffered: [.event, .group],
                                   showsKindPage: true,
                                   seed: .empty,
                                   flags: Flags(groups: true, tournaments: false),
                                   hasEligibleGroups: true))
    }

    @Test func aSeededKindTheFlagsDoNotOfferFallsBackToTheOnlyKindInRelease() {
        let opening = Self.opening(for: CreationSeed(kind: .group), flags: Self.releaseFlags)
        #expect(opening == Opening(kindsOffered: [.event],
                                   showsKindPage: false,
                                   seed: CreationSeed(kind: .event),
                                   flags: Self.releaseFlags,
                                   hasEligibleGroups: true))
    }

    /// The composition root reads the groups store once at opening; the fact rides untouched under any flags, so
    /// the step walk derives from the same context (`CreationSteps.eventSteps(opening:)` requires it).
    @Test(arguments: [true, false])
    func theEligibleGroupsFactRidesTheOpeningUntouched(hasEligibleGroups: Bool) {
        for flags in Self.allFlags {
            let opening = CreationWizardPolicy.opening(for: .empty,
                                                       flags: flags,
                                                       hasEligibleGroups: hasEligibleGroups)
            #expect(opening.hasEligibleGroups == hasEligibleGroups)
        }
    }

    @Test(arguments: [(CreateIntent.game, CreationKind.event), (.group, .group), (.tournament, .tournament)])
    func aParkedIntentMapsOntoItsKind(intent: CreateIntent, kind: CreationKind) {
        #expect(CreationKind(intent) == kind)
    }
}
