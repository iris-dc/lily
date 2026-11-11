import Foundation
import Observation

/// What the wizard's pages and chrome need from the shell model, kind-agnostic, so a page is generic over its own
/// kind's draft-editing view model alone and never over the other kinds' (the concrete `CreationWizardModel` is
/// generic over all three; only the composition root names its parameters). Observation rides the conforming
/// `@Observable` class, so views reading through the existential still track.
protocol CreationWizardControlling: AnyObject, Observable {
    /// The entries pushed beyond the stack's root, in order; read-only here, the shell alone binds it.
    var path: [CreationStep] { get }
    /// The entered kind's pages in walking order.
    var steps: [CreationStep] { get }
    var isSubmitting: Bool { get }
    var canSubmit: Bool { get }
    /// Pushes the next step when the current page owns no live issue; refused otherwise.
    func advance(from step: CreationStep)
    /// Pops back to `step`.
    func pop(to step: CreationStep)
    func allowsNext(from step: CreationStep) -> Bool
    /// The localized copy of the first live issue the step owns; `nil` when the page is clean.
    func blockingMessage(on step: CreationStep) -> String?
    /// The earliest earlier step whose stale issue blocks the final gate; the final page's hint names it.
    func blockedEarlierStep(before step: CreationStep) -> CreationStep?
    func submit() async
}
