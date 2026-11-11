import Foundation
import Observation

/// How the wizard makes the chosen kind's view model, injected by the composition root so this folder never knows a
/// concrete type. The seed's locked hosting group passes through to the kinds that host in one.
struct CreationWizardFactories<EventModel: EventDraftEditing,
                               GroupModel: GroupDraftEditing,
                               TournamentModel: TournamentDraftEditing> {
    let event: (EventGroupRef?) -> EventModel
    let group: () -> GroupModel
    let tournament: (EventGroupRef?) -> TournamentModel
}

/// The draft on screen as one value, whatever the kind, so the shell watches every flow's edits through one
/// `onChange` and the dirty rule has one yardstick shape.
nonisolated enum CreationDraft: Equatable, Sendable {
    case none
    case event(EventDraft)
    case group(GroupDraft)
    case tournament(TournamentDraft)
}

/// The wizard shell's state: the opening the policy decided, the kind fixed at init, the created
/// view model of that kind (generic parameters, so the shell stays statically typed and only the composition root
/// names concrete types; the pages read it through `CreationWizardControlling`), the navigation path of entered
/// steps, the user-edit flag behind the discard confirmation and the submit lock the chrome reads. The draft's
/// judging stays with the kind's view model; this type only routes its issues through `CreationSteps`
/// (`CreationWizardModel+Gating.swift`) and logs the flow's key events (kinds and issue ids only, never text).
@Observable
final class CreationWizardModel<EventModel: EventDraftEditing,
                                GroupModel: GroupDraftEditing,
                                TournamentModel: TournamentDraftEditing> {
    let opening: CreationWizardPolicy.Opening
    /// The kind this attempt makes, fixed by the normalized seed at init (the "+" menu and every other entry point
    /// name one; the policy fills an empty seed). A mispick is corrected by cancelling and reopening from the menu.
    let kind: CreationKind
    /// The entered kind's view model, made at init; the other two stay `nil` for the attempt.
    private(set) var eventModel: EventModel?
    private(set) var groupModel: GroupModel?
    private(set) var tournamentModel: TournamentModel?
    /// The entries pushed beyond the stack's root, in order: steps, and a place step's map picker; the root
    /// itself (the kind's first step) is never in here.
    var path: [CreationStep] = []
    /// Whether the user edited any field this attempt; a dirty wizard asks before discarding, a clean one closes
    /// silently. Latched by `noteDraftChanged()` on the first edit and never unlatched.
    private(set) var isDirty = false

    private let factories: CreationWizardFactories<EventModel, GroupModel, TournamentModel>
    private let logger: any Logging
    /// The draft as the factory made it, the yardstick for `noteDraftChanged()`; what differs from it beyond
    /// `prepare()`'s own write is the user's doing.
    private var pristine: CreationDraft = .none
    private var hasPrepared = false
    private var hasClosed = false

    init(opening: CreationWizardPolicy.Opening,
         factories: CreationWizardFactories<EventModel, GroupModel, TournamentModel>,
         logger: any Logging) {
        self.opening = opening
        self.factories = factories
        self.logger = logger
        // The policy always names a kind (an empty seed normalizes to the first offered); the event fallback is
        // the optional's tax, never taken.
        let kind = opening.seed.kind ?? .event
        self.kind = kind
        switch kind {
        case .event:
            let model = factories.event(opening.seed.lockedGroup)
            eventModel = model
            pristine = .event(model.draft)
        case .group:
            let model = factories.group()
            groupModel = model
            pristine = .group(model.draft)
        case .tournament:
            let model = factories.tournament(opening.seed.lockedGroup)
            tournamentModel = model
            pristine = .tournament(model.draft)
        }
        logger.info(.ui, "Creation wizard begun for \(name(of: kind))")
    }

    /// Runs the entered kind's prepare once, while its first step is already editable; no page's validity depends on
    /// it having finished. A run whose task died mid-await (the page's `.task` cancels with the page) is not burnt:
    /// the kinds' prepares are idempotent, so the next ask runs it again.
    func prepare() async {
        guard !hasPrepared, let model = active else { return }
        hasPrepared = true
        await model.prepare()
        if Task.isCancelled { hasPrepared = false }
    }

    /// The shell reports every draft change here; the first one the user made (anything `prepare()`'s own proposal
    /// does not account for) latches the dirty flag, so an edit during prepare's await counts like any other.
    func noteDraftChanged() {
        guard !isDirty else { return }
        isDirty = switch (draft, pristine) {
        case (.event(let draft), .event(let pristine)): Self.isUserEdit(draft, since: pristine)
        case (.group(let draft), .group(let pristine)): Self.isUserEdit(draft, since: pristine)
        case (.tournament(let draft), .tournament(let pristine)): Self.isUserEdit(draft, since: pristine)
        default: false
        }
    }

    /// Pushes the next step, or refuses and logs the issue that blocked it (the button is disabled too; this guard is
    /// the belt behind it). Only the entry on top may advance: a double-tapped Next landing mid-transition, or a tap
    /// gone stale across a pop, pushes nothing and can never skip a step.
    func advance(from step: CreationStep) {
        let top = path.last ?? steps.first
        guard top == step else { return }
        guard allowsNext(from: step) else {
            if let issue = firstBlockingIssue(on: step) {
                logger.debug(.ui, "Creation wizard refused Next: \(issue.logName)")
            }
            return
        }
        guard let index = steps.firstIndex(of: step), steps.indices.contains(index + 1) else { return }
        path.append(steps[index + 1])
    }

    /// Pops back to `step`: the path becomes the steps entered up to it, minus the first step, which is the root.
    func pop(to step: CreationStep) {
        guard let index = steps.firstIndex(of: step) else { return }
        path = Array(steps.prefix(index + 1).dropFirst())
    }

    /// Sends the draft through the kind's view model (idempotent by client id there); a call while one is in flight
    /// is dropped, and a create the backend accepted is logged once.
    func submit() async {
        guard let model = active, !model.isSubmitting else { return }
        await model.submit()
        if model.isDone { logger.info(.ui, "Creation wizard submitted \(name(of: kind))") }
    }

    /// The presenter reports the flow's one real dismissal (never a width-class re-host, which only moves the live
    /// flow between presenters); a flow that created nothing logs abandoned, once.
    func noteClosed() {
        guard !hasClosed else { return }
        hasClosed = true
        guard !isDone else { return }
        logger.info(.ui, "Creation wizard abandoned (kind: \(name(of: kind)))")
    }

    private func name(of kind: CreationKind) -> String { String(describing: kind) }

    /// Anything beyond `prepare()`'s own write is the user's edit: prepare only proposes a spot (a coordinate the
    /// user neither picked on the map nor took from a suggestion), so such a proposal is read as if unchanged —
    /// every kind's draft carries the same bookkeeping (`PlacePickingDraft`).
    private static func isUserEdit<Draft: PlacePickingDraft & Equatable>(_ draft: Draft, since pristine: Draft) -> Bool {
        var judged = draft
        if !judged.spotPickedOnMap, judged.suggestedName == nil {
            judged.coordinate = pristine.coordinate
        }
        return judged != pristine
    }
}
