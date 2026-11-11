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

    /// The "+" menu's items, cell by cell: the kinds the flags leave, the event always among them. The Release cell
    /// is the single-tap event button — one kind offered, so the menu collapses to one tap.
    @Test func theMenuOffersExactlyTheKindsTheFlagsLeave() {
        #expect(CreationWizardPolicy.kindsOffered(flags: Self.everythingOn) == [.event, .group, .tournament])
        #expect(CreationWizardPolicy.kindsOffered(flags: Flags(groups: true, tournaments: false)) == [.event, .group])
        #expect(CreationWizardPolicy.kindsOffered(flags: Flags(groups: false, tournaments: true)) == [.event, .tournament])
        #expect(CreationWizardPolicy.kindsOffered(flags: Self.releaseFlags) == [.event])
    }

    /// An empty seed (the single-tap Release "+") opens the event flow directly: the wizard always knows its kind,
    /// so its first page is that kind's Name step (the kind page left with the third design round, 2026-11-11).
    @Test(arguments: CreationWizardPolicyTests.allFlags)
    func anEmptySeedNormalizesToTheEventFlow(flags: Flags) {
        let opening = Self.opening(for: .empty, flags: flags)
        #expect(opening == Opening(kindsOffered: CreationWizardPolicy.kindsOffered(flags: flags),
                                   seed: CreationSeed(kind: .event),
                                   flags: flags,
                                   hasEligibleGroups: true))
    }

    @Test(arguments: CreationWizardPolicyTests.allFlags)
    func aSeededEventOpensTheEventFlowUnderAnyFlags(flags: Flags) {
        let opening = Self.opening(for: CreationSeed(kind: .event), flags: flags)
        #expect(opening.seed == CreationSeed(kind: .event))
        #expect(opening.kindsOffered == CreationWizardPolicy.kindsOffered(flags: flags))
    }

    @Test(arguments: [true, false])
    func aSeededGroupOpensTheGroupFlowWhileGroupsAreOn(tournaments: Bool) {
        let opening = Self.opening(for: CreationSeed(kind: .group),
                                   flags: Flags(groups: true, tournaments: tournaments))
        #expect(opening.seed == CreationSeed(kind: .group))
    }

    @Test(arguments: [true, false])
    func aSeededTournamentOpensTheTournamentFlowWhileTournamentsAreOn(groups: Bool) {
        let opening = Self.opening(for: CreationSeed(kind: .tournament),
                                   flags: Flags(groups: groups, tournaments: true))
        #expect(opening.seed == CreationSeed(kind: .tournament))
    }

    @Test func aGameFromAGroupKeepsItsLockedGroup() {
        let seed = CreationSeed(kind: .event, lockedGroup: Self.group)
        let opening = Self.opening(for: seed, flags: Self.everythingOn)
        #expect(opening == Opening(kindsOffered: [.event, .group, .tournament],
                                   seed: seed,
                                   flags: Self.everythingOn,
                                   hasEligibleGroups: true))
    }

    @Test func aTournamentFromAGroupKeepsItsLockedGroup() {
        let seed = CreationSeed(kind: .tournament, lockedGroup: Self.group)
        let opening = Self.opening(for: seed, flags: Self.everythingOn)
        #expect(opening.seed == seed)
    }

    /// A seeded kind the flags do not offer cannot open its flow; it falls back to the event, which always ships.
    @Test func aSeededKindTheFlagsDoNotOfferFallsBackToTheEvent() {
        let noTournaments = Self.opening(for: CreationSeed(kind: .tournament),
                                         flags: Flags(groups: true, tournaments: false))
        #expect(noTournaments.seed == CreationSeed(kind: .event))

        let release = Self.opening(for: CreationSeed(kind: .group), flags: Self.releaseFlags)
        #expect(release == Opening(kindsOffered: [.event],
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
