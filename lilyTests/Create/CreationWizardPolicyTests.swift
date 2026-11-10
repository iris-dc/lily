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

    @Test func thePlusWithEverythingOnOpensTheKindPageWithAllThreeKinds() {
        let opening = CreationWizardPolicy.opening(for: .empty, flags: Self.everythingOn)
        #expect(opening == Opening(kindsOffered: [.event, .group, .tournament], showsKindPage: true, seed: .empty))
    }

    @Test func thePlusWithoutTournamentsOffersEventAndGroup() {
        let opening = CreationWizardPolicy.opening(for: .empty, flags: Flags(groups: true, tournaments: false))
        #expect(opening == Opening(kindsOffered: [.event, .group], showsKindPage: true, seed: .empty))
    }

    @Test func thePlusWithoutGroupsOffersEventAndTournament() {
        let opening = CreationWizardPolicy.opening(for: .empty, flags: Flags(groups: false, tournaments: true))
        #expect(opening == Opening(kindsOffered: [.event, .tournament], showsKindPage: true, seed: .empty))
    }

    @Test func theReleasePlusSkipsTheKindPageAndOpensTheEventFlow() {
        let opening = CreationWizardPolicy.opening(for: .empty, flags: Self.releaseFlags)
        #expect(opening == Opening(kindsOffered: [.event], showsKindPage: false, seed: CreationSeed(kind: .event)))
    }

    @Test(arguments: CreationWizardPolicyTests.allFlags)
    func aSeededEventOpensTheEventFlowUnderAnyFlags(flags: Flags) {
        let opening = CreationWizardPolicy.opening(for: CreationSeed(kind: .event), flags: flags)
        #expect(!opening.showsKindPage)
        #expect(opening.seed == CreationSeed(kind: .event))
        #expect(opening.kindsOffered == CreationWizardPolicy.kindsOffered(flags: flags))
    }

    @Test(arguments: [true, false])
    func aSeededGroupOpensTheGroupFlowWhileGroupsAreOn(tournaments: Bool) {
        let opening = CreationWizardPolicy.opening(for: CreationSeed(kind: .group),
                                                   flags: Flags(groups: true, tournaments: tournaments))
        #expect(!opening.showsKindPage)
        #expect(opening.seed == CreationSeed(kind: .group))
    }

    @Test(arguments: [true, false])
    func aSeededTournamentOpensTheTournamentFlowWhileTournamentsAreOn(groups: Bool) {
        let opening = CreationWizardPolicy.opening(for: CreationSeed(kind: .tournament),
                                                   flags: Flags(groups: groups, tournaments: true))
        #expect(!opening.showsKindPage)
        #expect(opening.seed == CreationSeed(kind: .tournament))
    }

    @Test func aGameFromAGroupKeepsItsLockedGroupAndSkipsTheKindPage() {
        let seed = CreationSeed(kind: .event, lockedGroup: Self.group)
        let opening = CreationWizardPolicy.opening(for: seed, flags: Self.everythingOn)
        #expect(opening == Opening(kindsOffered: [.event, .group, .tournament], showsKindPage: false, seed: seed))
    }

    @Test func aTournamentFromAGroupKeepsItsLockedGroupAndSkipsTheKindPage() {
        let seed = CreationSeed(kind: .tournament, lockedGroup: Self.group)
        let opening = CreationWizardPolicy.opening(for: seed, flags: Self.everythingOn)
        #expect(!opening.showsKindPage)
        #expect(opening.seed == seed)
    }

    @Test func aSeededKindTheFlagsDoNotOfferFallsBackToTheKindPage() {
        let opening = CreationWizardPolicy.opening(for: CreationSeed(kind: .tournament),
                                                   flags: Flags(groups: true, tournaments: false))
        #expect(opening == Opening(kindsOffered: [.event, .group], showsKindPage: true, seed: .empty))
    }

    @Test func aSeededKindTheFlagsDoNotOfferFallsBackToTheOnlyKindInRelease() {
        let opening = CreationWizardPolicy.opening(for: CreationSeed(kind: .group), flags: Self.releaseFlags)
        #expect(opening == Opening(kindsOffered: [.event], showsKindPage: false, seed: CreationSeed(kind: .event)))
    }

    @Test(arguments: [(CreateIntent.game, CreationKind.event), (.group, .group), (.tournament, .tournament)])
    func aParkedIntentMapsOntoItsKind(intent: CreateIntent, kind: CreationKind) {
        #expect(CreationKind(intent) == kind)
    }
}
