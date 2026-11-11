import Foundation

/// The sheets Explore presents: the creation wizard for anything new (seeded with the kind the "+" menu or a
/// shortcut named), and sign-in for a guest who asked to create. The screen holds one of these as its presented
/// sheet; a keyboard shortcut's `CreateIntent` maps onto a seeded wizard.
nonisolated enum ExploreSheet: Identifiable, Hashable, Sendable {
    /// The creation wizard, carrying what the entry point seeds it with (a menu item or shortcut names its kind).
    case wizard(CreationSeed)
    case signIn

    /// Explicit now that a case carries a payload: one wizard presentation at a time, whatever its seed.
    var id: String {
        switch self {
        case .wizard: "wizard"
        case .signIn: "signIn"
        }
    }

    /// The sheet a keyboard shortcut's intent asks for: the wizard, seeded with the intent's kind.
    init(_ intent: CreateIntent) {
        self = .wizard(CreationSeed(kind: CreationKind(intent)))
    }
}
