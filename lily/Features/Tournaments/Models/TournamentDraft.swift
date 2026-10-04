import Foundation

/// What an organiser fills in to create a tournament, or changes on one they run. Validated on device against the limits
/// the backend enforces (`AppConfig.Tournaments`, text lengths in UTF-16 units as the backend counts them), so a draft
/// that passes never earns a 400; `issues(now:rules:)` names what is still wrong.
nonisolated struct TournamentDraft: Equatable, Sendable {
    /// Chosen once per draft and sent with every attempt: the backend uses it as the tournament id, so a create
    /// repeated after a lost answer finds its tournament instead of making a second one. Lower-case, as stored.
    let clientId: String
    var name = ""
    var description = ""
    var type: EventType = .football
    var format: TournamentFormat = .singleElimination
    var teamSize = AppConfig.Tournaments.defaultTeamSize
    var maxEntries = AppConfig.Tournaments.defaultMaxEntries
    /// `nil` follows the type's default (team sports draw, racket sports do not) until the organiser chooses.
    var allowsDraws: Bool?
    var startsAt: Date
    /// `nil` closes registration at the start.
    var registrationClosesAt: Date?
    var locationName = ""
    /// Starts from the user's position and is moved on the map; required.
    var coordinate: Coordinate?
    /// The group to host the tournament in; `nil` for one of its own. A hosted tournament takes the group's visibility.
    var group: EventGroupRef?
    var visibility: GroupVisibility = .public

    init(startsAt: Date, clientId: String = UUID().uuidString.lowercased()) {
        self.clientId = clientId
        self.startsAt = startsAt
    }

    /// The tournament as a draft, for the organiser's edit: `clientId` is its id.
    init(editing tournament: Tournament) {
        clientId = tournament.id
        name = tournament.name
        description = tournament.description ?? ""
        type = tournament.type
        format = tournament.format
        teamSize = tournament.teamSize
        maxEntries = tournament.maxEntries
        allowsDraws = tournament.allowsDraws
        startsAt = tournament.startsAt
        registrationClosesAt = tournament.registrationClosesAt
        locationName = tournament.locationName
        coordinate = tournament.location.coordinate
        group = tournament.group
        visibility = tournament.visibility
    }

    /// What a draft is judged against beyond the backend's limits: a create keeps the app's lead-time margin, an edit
    /// only needs the future and never fewer entries than are already in, and once the tournament started the schedule
    /// is fixed and not judged at all.
    struct Rules: Equatable, Sendable {
        let minimumLeadTime: TimeInterval
        let minimumEntries: Int
        /// Whether the start and the deadline are judged. Not once the tournament started: the form shows them
        /// read-only and the payload repeats them as stored, which the backend compares and never re-validates.
        let judgesSchedule: Bool

        static let creation = Rules(minimumLeadTime: AppConfig.Tournaments.minimumLeadTime,
                                    minimumEntries: AppConfig.Tournaments.entriesRange.lowerBound,
                                    judgesSchedule: true)

        /// An edit: no lead time, never fewer entries than are in; `isLocked` once the tournament started.
        static func editing(entryCount: Int, isLocked: Bool = false) -> Rules {
            Rules(minimumLeadTime: AppConfig.Events.Editing.minimumLeadTime,
                  minimumEntries: max(AppConfig.Tournaments.entriesRange.lowerBound, entryCount),
                  judgesSchedule: !isLocked)
        }

        /// The entries the form's stepper offers under these rules for a format: from the floor to the format's cap.
        func entriesRange(for format: TournamentFormat) -> ClosedRange<Int> {
            minimumEntries...max(minimumEntries, format.entriesRange.upperBound)
        }
    }

    /// One reason a draft cannot be sent, in the order the form shows its fields.
    enum Issue: Hashable, Sendable {
        case nameTooShort
        case nameTooLong
        case teamSizeOutOfRange
        case maxEntriesOutOfRange
        /// An edit asked for fewer entries than are already in.
        case maxEntriesBelowEntries
        case startsAtTooSoon
        case registrationClosesAfterStart
        case locationNameMissing
        case locationNameTooLong
        case coordinateMissing
        case descriptionTooLong
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedLocationName: String { locationName.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// `nil` when nothing was written, so the payload omits the field.
    var trimmedDescription: String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    var isTeam: Bool { teamSize > 1 }
    var resolvedAllowsDraws: Bool { allowsDraws ?? type.allowsDrawsByDefault }
    /// A hosted tournament's visibility is its group's; the picker's choice applies to a standalone one.
    var effectiveVisibility: GroupVisibility { group?.visibility ?? visibility }

    /// The earliest start the form accepts, relative to `now`.
    static func earliestStart(now: Date, rules: Rules = .creation) -> Date {
        now.addingTimeInterval(rules.minimumLeadTime)
    }

    /// Where the deadline lands when one is switched on: a day before the start, but never in the past.
    static func proposedDeadline(before startsAt: Date, now: Date) -> Date {
        max(now, startsAt.addingTimeInterval(-AppConfig.Tournaments.defaultDeadlineLead))
    }

    /// Everything that keeps the draft from being sent, in form order; empty means it can go.
    func issues(now: Date, rules: Rules = .creation) -> [Issue] {
        tournamentIssues(rules: rules) + scheduleIssues(now: now, rules: rules) + placeIssues() + detailIssues()
    }

    func isValid(now: Date, rules: Rules = .creation) -> Bool {
        issues(now: now, rules: rules).isEmpty
    }

    /// The Tournament section: name, team size, entries.
    private func tournamentIssues(rules: Rules) -> [Issue] {
        var issues: [Issue] = []
        let limits = AppConfig.Tournaments.self
        if trimmedName.wireLength < limits.nameLength.lowerBound { issues.append(.nameTooShort) }
        if trimmedName.wireLength > limits.nameLength.upperBound { issues.append(.nameTooLong) }
        if !limits.teamSizeRange.contains(teamSize) { issues.append(.teamSizeOutOfRange) }
        if !format.entriesRange.contains(maxEntries) {
            issues.append(.maxEntriesOutOfRange)
        } else if maxEntries < rules.minimumEntries {
            issues.append(.maxEntriesBelowEntries)
        }
        return issues
    }

    /// When: the start and the deadline before it.
    private func scheduleIssues(now: Date, rules: Rules) -> [Issue] {
        guard rules.judgesSchedule else { return [] }
        var issues: [Issue] = []
        if startsAt < Self.earliestStart(now: now, rules: rules) { issues.append(.startsAtTooSoon) }
        if let registrationClosesAt, registrationClosesAt >= startsAt { issues.append(.registrationClosesAfterStart) }
        return issues
    }

    /// Where: the place name and the spot.
    private func placeIssues() -> [Issue] {
        var issues: [Issue] = []
        let maxLength = AppConfig.Events.Creation.locationNameMaxLength
        if trimmedLocationName.isEmpty { issues.append(.locationNameMissing) }
        if trimmedLocationName.wireLength > maxLength { issues.append(.locationNameTooLong) }
        if coordinate == nil { issues.append(.coordinateMissing) }
        return issues
    }

    private func detailIssues() -> [Issue] {
        trimmedDescription.wireLength > AppConfig.Tournaments.descriptionMaxLength ? [.descriptionTooLong] : []
    }

    /// The tournament this draft becomes once stored: the caller organises it, nobody has entered, and the room's
    /// epoch starts at one. What the mock repository and the test fake answer for a create.
    func makeTournament(organizerUserId: String, organizerName: String, coordinate: Coordinate, now: Date) -> Tournament {
        Tournament(id: clientId,
                   name: trimmedName,
                   description: trimmedDescription,
                   type: type,
                   format: format,
                   visibility: effectiveVisibility,
                   teamSize: teamSize,
                   maxEntries: maxEntries,
                   allowsDraws: resolvedAllowsDraws,
                   startsAt: startsAt,
                   registrationClosesAt: registrationClosesAt,
                   location: EventLocation(name: trimmedLocationName, coordinate: coordinate),
                   organizerUserId: organizerUserId,
                   organizerName: organizerName,
                   group: group,
                   createdAt: now)
    }
}

nonisolated extension EventType {
    /// Whether a match may end level unless the organiser says otherwise: team sports draw, racket sports, esports
    /// and board games do not. The backend applies the same default when the field is omitted; the app always sends it.
    var allowsDrawsByDefault: Bool {
        switch self {
        case .football, .basketball, .volleyball: true
        default: false
        }
    }
}
