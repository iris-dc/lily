import Foundation

/// The rules behind Explore's create sheets: which sheet a request opens for whom, and what a keyboard shortcut's
/// parked intent earns when Explore comes to consume it.
nonisolated enum CreateIntentPolicy {
    /// Whether the intent is taken off `AppNavigation`, and the sheet to present, if any.
    struct Decision: Equatable, Sendable {
        let consumes: Bool
        let present: ExploreSheet?
    }

    /// Only a signed-in user hosts or founds; a guest is offered sign-in and comes back to the menu afterwards.
    static func sheet(for requested: ExploreSheet, isSignedIn: Bool) -> ExploreSheet {
        isSignedIn ? requested : .signIn
    }

    /// No intent changes nothing. An intent over a sheet already up is consumed without presenting: ⌘N inside the
    /// create form must not replace it and lose what was typed, and the intent is still cleared so it cannot pop
    /// later. Otherwise the intent's sheet for a user, sign-in for a guest.
    static func decide(intent: CreateIntent?, presentedSheet: ExploreSheet?, isSignedIn: Bool) -> Decision {
        guard let intent else { return Decision(consumes: false, present: nil) }
        guard presentedSheet == nil else { return Decision(consumes: true, present: nil) }
        return Decision(consumes: true, present: sheet(for: ExploreSheet(intent), isSignedIn: isSignedIn))
    }
}
