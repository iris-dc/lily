import Foundation
import Observation

/// How the wizard makes the chosen kind's view model, injected by the composition root so this folder never knows a
/// concrete type. One member per kind as their flows land; only the event factory exists in slice 2.
struct CreationWizardFactories<EventModel: EventDraftEditing> {
    /// The event flow's model; the seed's locked hosting group passes through to it.
    let event: (EventGroupRef?) -> EventModel
}

/// The wizard shell's state: the opening the policy decided, the kind entered once per attempt, the lazily created
/// view model of that kind (a generic parameter, so the shell and its pages stay statically typed and only the
/// composition root names a concrete type), the navigation path of entered steps, the user-edit flag behind the discard confirmation
/// and the submit lock the chrome reads. The draft's judging stays with the kind's view model; this type only routes
/// its issues through `CreationSteps` and logs the flow's key events (kinds and issue ids only, never text).
@Observable
final class CreationWizardModel<EventModel: EventDraftEditing> {
    let opening: CreationWizardPolicy.Opening
    /// The kind this attempt makes, set once: by the seed at init, or by the kind page's pick. Never unset — back
    /// stops at the kind's first step, so a mispick is corrected by cancelling and reopening.
    private(set) var kind: CreationKind?
    /// The event flow's view model, made on kind entry; `nil` until then and for the kinds without pages.
    private(set) var eventModel: EventModel?
    /// The entries pushed beyond the stack's root, in order: steps, and the place step's map picker; the root
    /// itself (the kind page, or the first step when the policy skips it) is never in here.
    var path: [CreationStep] = []
    /// Whether the user edited any field this attempt; a dirty wizard asks before discarding, a clean one closes
    /// silently. Latched by `noteDraftChanged()` on the first edit and never unlatched.
    private(set) var isDirty = false

    private let factories: CreationWizardFactories<EventModel>
    private let logger: any Logging
    /// The draft as the factory made it, the yardstick for `noteDraftChanged()`; what differs from it beyond
    /// `prepare()`'s own write is the user's doing.
    private var pristineDraft: EventDraft?
    private var hasPrepared = false
    private var hasClosed = false

    init(opening: CreationWizardPolicy.Opening, factories: CreationWizardFactories<EventModel>, logger: any Logging) {
        self.opening = opening
        self.factories = factories
        self.logger = logger
        if let kind = opening.seed.kind { enter(kind) }
    }

    /// The entered kind's pages in walking order, derived from the opening alone (its flags, seed and
    /// eligible-groups fact decide the hosting-group page) so the walk is deterministic per attempt; empty before a
    /// kind is entered.
    var steps: [CreationStep] { kind.map { CreationSteps.steps(for: $0, opening: opening) } ?? [] }

    /// The draft on screen, for the shell to watch for edits; `nil` before a kind is entered.
    var draft: EventDraft? { eventModel?.draft }

    var isSubmitting: Bool { eventModel?.isSubmitting ?? false }
    var canSubmit: Bool { eventModel?.canSubmit ?? false }
    /// The backend answered; the shell dismisses when it turns true.
    var isDone: Bool { eventModel?.isDone ?? false }

    /// Fixes the kind for this attempt and makes its view model; a second call is dropped (the pick is one-way), and
    /// a kind whose pages have not landed is refused before the kind is fixed, so the wizard is never stuck on it.
    func enter(_ kind: CreationKind) {
        guard self.kind == nil else { return }
        guard let first = CreationSteps.steps(for: kind, opening: opening).first else {
            logger.warning(.ui, "Creation wizard has no pages for \(name(of: kind)) yet")
            return
        }
        self.kind = kind
        if case .event = kind {
            let model = factories.event(opening.seed.lockedGroup)
            eventModel = model
            pristineDraft = model.draft
        }
        if opening.showsKindPage { path.append(first) }
        logger.info(.ui, "Creation wizard begun for \(name(of: kind))")
    }

    /// Runs the entered kind's prepare once, while its first step is already editable; no page's validity depends on
    /// it having finished.
    func prepare() async {
        guard !hasPrepared, let model = eventModel else { return }
        hasPrepared = true
        await model.prepare()
    }

    /// The shell reports every draft change here; the first one the user made (anything `prepare()`'s own proposal
    /// does not account for) latches the dirty flag, so an edit during prepare's await counts like any other.
    func noteDraftChanged() {
        guard !isDirty, let draft = eventModel?.draft, let pristine = pristineDraft else { return }
        isDirty = Self.isUserEdit(draft, since: pristine)
    }

    /// Next may move forward exactly when the step owns none of the live issues.
    func allowsNext(from step: CreationStep) -> Bool {
        switch step {
        case .event(let eventStep): CreationSteps.allowsNext(from: eventStep, issues: eventIssues)
        case .eventMap: false
        }
    }

    /// The first live issue the step owns, in field order: what the page's hint shows and a refused Next logs.
    func firstBlockingIssue(on step: CreationStep) -> EventDraft.Issue? {
        switch step {
        case .event(let eventStep): eventIssues.first { CreationSteps.eventStep(owning: $0) == eventStep }
        case .eventMap: nil
        }
    }

    /// The earliest earlier step whose stale issue blocks the final gate; the final page's hint names it.
    func blockedEarlierStep(before step: CreationStep) -> CreationStep? {
        guard let index = steps.firstIndex(of: step) else { return nil }
        return steps.prefix(upTo: index).first { !allowsNext(from: $0) }
    }

    /// Pushes the next step, or refuses and logs the issue that blocked it (the button is disabled too; this guard is
    /// the belt behind it). Only the entry on top may advance: a double-tapped Next landing mid-transition, or a tap
    /// gone stale across a pop, pushes nothing and can never skip a step.
    func advance(from step: CreationStep) {
        let top = path.last ?? (opening.showsKindPage ? nil : steps.first)
        guard top == step else { return }
        guard allowsNext(from: step) else {
            if let issue = firstBlockingIssue(on: step) {
                logger.debug(.ui, "Creation wizard refused Next: \(String(describing: issue))")
            }
            return
        }
        guard let index = steps.firstIndex(of: step), steps.indices.contains(index + 1) else { return }
        path.append(steps[index + 1])
    }

    /// Pops back to `step`: the path becomes the steps entered up to it, minus the root when the first step is the root.
    func pop(to step: CreationStep) {
        guard let index = steps.firstIndex(of: step) else { return }
        let entered = steps.prefix(index + 1)
        path = Array(opening.showsKindPage ? entered : entered.dropFirst())
    }

    /// Sends the draft through the kind's view model (idempotent by client id there); a call while one is in flight
    /// is dropped, and a create the backend accepted is logged once.
    func submit() async {
        guard let model = eventModel, !model.isSubmitting else { return }
        await model.submit()
        if model.isDone, let kind { logger.info(.ui, "Creation wizard submitted \(name(of: kind))") }
    }

    /// The presenter reports the flow's one real dismissal (never a width-class re-host, which only moves the live
    /// flow between presenters); a flow that created nothing logs abandoned, once.
    func noteClosed() {
        guard !hasClosed else { return }
        hasClosed = true
        guard !isDone else { return }
        logger.info(.ui, "Creation wizard abandoned (kind: \(kind.map(name(of:)) ?? "none"))")
    }

    private var eventIssues: [EventDraft.Issue] { eventModel?.issues ?? [] }

    private func name(of kind: CreationKind) -> String { String(describing: kind) }

    /// Anything beyond `prepare()`'s own write is the user's edit: prepare only proposes a spot (a coordinate the
    /// user neither picked on the map nor took from a suggestion), so such a proposal is read as if unchanged.
    private static func isUserEdit(_ draft: EventDraft, since pristine: EventDraft) -> Bool {
        var judged = draft
        if !judged.spotPickedOnMap, judged.suggestedName == nil {
            judged.coordinate = pristine.coordinate
        }
        return judged != pristine
    }
}
