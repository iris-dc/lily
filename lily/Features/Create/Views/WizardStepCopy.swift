import Foundation

/// The chrome copy and identifiers of every wizard step, per kind, read by `WizardStepScaffold`: computed switches,
/// so the per-step mapping stays in one place (and outside the complexity rule, which exempts computed properties).
nonisolated extension CreationStep {
    private typealias Copy = AppBranding.Create

    /// The step's navigation title; the map cases are never scaffolded (the picker draws its own screen) and answer
    /// their place step's title for exhaustiveness alone.
    var wizardTitle: String {
        switch self {
        case .event(.name): Copy.eventName
        case .event(.type): Copy.eventType
        case .event(.when): Copy.eventWhen
        case .event(.group): Copy.eventGroup
        case .event(.place), .eventMap: Copy.eventPlace
        case .event(.players): Copy.eventPlayers
        case .event(.details): Copy.eventDetails
        case .group(.name): Copy.groupName
        case .group(.description): Copy.groupDescription
        case .group(.type): Copy.groupType
        case .group(.visibility): Copy.groupVisibility
        case .group(.place), .groupMap: Copy.groupPlace
        case .group(.permissions): Copy.groupPermissions
        case .tournament(.name): Copy.tournamentName
        case .tournament(.type): Copy.tournamentType
        case .tournament(.format): Copy.tournamentFormat
        case .tournament(.schedule): Copy.tournamentSchedule
        case .tournament(.group): Copy.tournamentGroup
        case .tournament(.place), .tournamentMap: Copy.tournamentPlace
        case .tournament(.entries): Copy.tournamentEntries
        case .tournament(.whoMayJoin): Copy.tournamentWho
        case .tournament(.details): Copy.tournamentDetails
        }
    }

    /// The one short line under a step title whose purpose needs extra knowledge; the plain steps carry none.
    var wizardCaption: String? {
        switch self {
        case .event(.group): Copy.eventGroupCaption
        case .event(.place): Copy.eventPlaceCaption
        case .event(.players): Copy.eventPlayersCaption
        case .event(.details): Copy.eventDetailsCaption
        case .group(.description): Copy.groupDescriptionCaption
        case .group(.visibility): Copy.groupVisibilityCaption
        case .group(.place): Copy.groupPlaceCaption
        case .group(.permissions): Copy.groupPermissionsCaption
        case .tournament(.schedule): Copy.tournamentScheduleCaption
        case .tournament(.group): Copy.tournamentGroupCaption
        case .tournament(.place): Copy.tournamentPlaceCaption
        case .tournament(.entries): Copy.tournamentEntriesCaption
        case .tournament(.whoMayJoin): Copy.tournamentWhoCaption
        case .tournament(.details): Copy.tournamentDetailsCaption
        case .event, .group, .tournament, .eventMap, .groupMap, .tournamentMap: nil
        }
    }

    /// The final step's button reuses its kind's existing submit copy.
    var wizardSubmitTitle: String {
        switch self {
        case .event, .eventMap: AppBranding.Events.Create.submit
        case .group, .groupMap: AppBranding.Groups.Create.submit
        case .tournament, .tournamentMap: AppBranding.Tournaments.Create.submit
        }
    }

    /// The final step's button keeps its kind's existing submit identifier, so the edit sheets and the wizard agree.
    var wizardSubmitIdentifier: String {
        switch self {
        case .event, .eventMap: AccessibilityIdentifiers.createSubmit
        case .group, .groupMap: AccessibilityIdentifiers.createGroupSubmit
        case .tournament, .tournamentMap: AccessibilityIdentifiers.tournamentSubmit
        }
    }
}
