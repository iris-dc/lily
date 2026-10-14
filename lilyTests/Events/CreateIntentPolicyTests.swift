import Testing
@testable import lily

struct CreateIntentPolicyTests {
    private typealias Decision = CreateIntentPolicy.Decision

    @Test(arguments: [(CreateIntent.game, ExploreSheet.createGame), (.group, .createGroup), (.tournament, .createTournament)])
    func aSignedInUsersIntentOpensTheMatchingSheet(intent: CreateIntent, sheet: ExploreSheet) {
        let decision = CreateIntentPolicy.decide(intent: intent, presentedSheet: nil, isSignedIn: true)
        #expect(decision == Decision(consumes: true, present: sheet))
    }

    @Test(arguments: [CreateIntent.game, .group, .tournament])
    func aGuestsIntentOpensSignIn(intent: CreateIntent) {
        let decision = CreateIntentPolicy.decide(intent: intent, presentedSheet: nil, isSignedIn: false)
        #expect(decision == Decision(consumes: true, present: .signIn))
    }

    @Test(arguments: [ExploreSheet.createGame, .signIn], [true, false])
    func anIntentOverAnOpenSheetIsConsumedWithoutPresenting(presentedSheet: ExploreSheet, isSignedIn: Bool) {
        let decision = CreateIntentPolicy.decide(intent: .game, presentedSheet: presentedSheet, isSignedIn: isSignedIn)
        #expect(decision == Decision(consumes: true, present: nil))
    }

    @Test(arguments: [nil, ExploreSheet.createGroup], [true, false])
    func noIntentChangesNothing(presentedSheet: ExploreSheet?, isSignedIn: Bool) {
        let decision = CreateIntentPolicy.decide(intent: nil, presentedSheet: presentedSheet, isSignedIn: isSignedIn)
        #expect(decision == Decision(consumes: false, present: nil))
    }

    @Test func thePlusMenuSendsAGuestToSignIn() {
        #expect(CreateIntentPolicy.sheet(for: .createGroup, isSignedIn: false) == .signIn)
    }

    @Test func thePlusMenuOpensTheFormForAUser() {
        #expect(CreateIntentPolicy.sheet(for: .createTournament, isSignedIn: true) == .createTournament)
    }
}
