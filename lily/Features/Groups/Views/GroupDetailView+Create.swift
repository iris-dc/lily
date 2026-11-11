import SwiftUI

/// The creation wizard from a group's screen: a new game or tournament opens seeded with the kind and this group
/// locked, so the flow starts on that kind's first step and the hosting-group page is skipped. The presentation mirrors Explore's —
/// a full-screen cover on a compact width, a form sheet otherwise, both over the one `presentedSheet`, with the
/// model owned above the presenters so a width-class change mid-flow re-hosts the flow instead of destroying it.
extension GroupDetailView {
    /// Whether the wizard is up and rides the full-screen cover: only on a compact width.
    var presentsWizardAsCover: Bool {
        guard let presentedSheet, presentedSheet.isWizard else { return false }
        return layoutMode == .compact
    }

    /// The two presenters split `presentedSheet` between them: each shows it only while the other does not claim it.
    var sheetItem: Binding<DetailSheet?> {
        Binding(get: { presentsWizardAsCover ? nil : presentedSheet }, set: { presentedSheet = $0 })
    }

    var wizardCoverItem: Binding<DetailSheet?> {
        Binding(get: { presentsWizardAsCover ? presentedSheet : nil }, set: { presentedSheet = $0 })
    }

    /// The wizard both presenters host; the model was made when the flow was presented. The wizard mounts its own
    /// popup and dismissal rules, so the presenters add sizing only.
    @ViewBuilder var wizardContent: some View {
        if let wizardModel {
            CreationWizardView(model: wizardModel, errorCenter: dependencies.errorCenter)
        }
    }

    /// The game is hosted in this group, and lands in the segment behind the wizard at once.
    func presentCreateEvent() {
        presentWizard(.createEvent, kind: .event)
    }

    /// The tournament is hosted in this group, and lands in the segment behind the wizard at once.
    func presentCreateTournament() {
        presentWizard(.createTournament, kind: .tournament)
    }

    /// A real dismissal cleared `presentedSheet` through a presenter's item binding; a re-host (the other presenter
    /// taking the wizard over on a width-class change) did not, and the flow keeps its model. The real dismissal is
    /// also where the flow's close is booked (the abandoned log, once and never after a create).
    func clearWizardAfterDismiss() {
        guard presentedSheet == nil else { return }
        wizardModel?.noteClosed()
        wizardModel = nil
    }

    private func presentWizard(_ sheet: DetailSheet, kind: CreationKind) {
        wizardModel = dependencies.makeCreationWizardModel(
            seed: CreationSeed(kind: kind, lockedGroup: group.ref),
            onCreatedEvent: events.add,
            // Unreachable from a seeded flow (the kind pick is one-way); the factories still need every kind's landing.
            onCreatedGroup: { [dependencies] in dependencies.navigation.open(group: $0) },
            onCreatedTournament: { tournaments.add($0.tournament) })
        presentedSheet = sheet
    }
}
