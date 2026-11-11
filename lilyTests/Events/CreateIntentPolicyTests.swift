import Testing
@testable import lily

struct CreateIntentPolicyTests {
    private typealias Decision = CreateIntentPolicy.Decision

    @Test(arguments: [
        (CreateIntent.game, CreationKind.event),
        (CreateIntent.group, .group),
        (CreateIntent.tournament, .tournament)
    ])
    func aSignedInUsersIntentOpensTheWizardSeededWithItsKind(intent: CreateIntent, kind: CreationKind) {
        let decision = CreateIntentPolicy.decide(intent: intent, presentedSheet: nil, isSignedIn: true)
        #expect(decision == Decision(consumes: true, present: .wizard(CreationSeed(kind: kind))))
    }

    @Test(arguments: [CreateIntent.game, .group, .tournament])
    func aGuestsIntentOpensSignIn(intent: CreateIntent) {
        let decision = CreateIntentPolicy.decide(intent: intent, presentedSheet: nil, isSignedIn: false)
        #expect(decision == Decision(consumes: true, present: .signIn))
    }

    @Test(arguments: [ExploreSheet.wizard(CreationSeed(kind: .event)), .signIn], [true, false])
    func anIntentOverAnOpenSheetIsConsumedWithoutPresenting(presentedSheet: ExploreSheet, isSignedIn: Bool) {
        let decision = CreateIntentPolicy.decide(intent: .game, presentedSheet: presentedSheet, isSignedIn: isSignedIn)
        #expect(decision == Decision(consumes: true, present: nil))
    }

    @Test(arguments: [nil, ExploreSheet.wizard(CreationSeed())], [true, false])
    func noIntentChangesNothing(presentedSheet: ExploreSheet?, isSignedIn: Bool) {
        let decision = CreateIntentPolicy.decide(intent: nil, presentedSheet: presentedSheet, isSignedIn: isSignedIn)
        #expect(decision == Decision(consumes: false, present: nil))
    }

    @Test func thePlusSendsAGuestToSignIn() {
        #expect(CreateIntentPolicy.sheet(for: .wizard(.empty), isSignedIn: false) == .signIn)
    }

    @Test func thePlusOpensTheWizardForAUser() {
        let wizard = ExploreSheet.wizard(.empty)
        #expect(CreateIntentPolicy.sheet(for: wizard, isSignedIn: true) == wizard)
    }
}
