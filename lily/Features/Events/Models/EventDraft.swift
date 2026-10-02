import Foundation

/// What a host fills in to create an event, or changes on one they host. Validated on device against the limits the
/// backend enforces (`AppConfig.Events.Creation`, text lengths in UTF-16 units as the backend counts them), so a draft
/// that passes never earns a 400; `issues(now:rules:)` names what is still wrong.
nonisolated struct EventDraft: Equatable, Sendable {
    /// Chosen once per draft and sent with every attempt: a create repeated after a lost answer finds its event on
    /// the backend instead of making a second one, because the backend uses it as the event id. Lower-case, as the
    /// backend stores and returns it, so the mock and the real answer carry the same id.
    let clientId: String
    var title = ""
    var type: EventType = .football
    var startsAt: Date
    var locationName = ""
    /// Starts from the user's position and is moved on the map; required.
    var coordinate: Coordinate?
    /// The stepper's value, kept while the limit is `.unlimited` so switching back finds it again.
    var capacity = AppConfig.Events.Creation.defaultCapacity
    /// Whether `capacity` caps the game, is the number needed, or is not sent at all.
    var playerLimit: PlayerLimit = .maximum
    var description = ""
    var lookingFor = ""
    /// `nil` means any level.
    var skillLevel: SkillLevel?
    /// Per person; `nil` or zero means free.
    var price: Decimal?
    /// The group to host the game in; `nil` for a game of its own. The ref, not a bare id, so the stored event can
    /// show its badge without a second lookup.
    var group: EventGroupRef?

    init(startsAt: Date, clientId: String = UUID().uuidString.lowercased()) {
        self.clientId = clientId
        self.startsAt = startsAt
    }

    /// The event as a draft, for the host's edit: `clientId` is the event's id, and `updating(with:)` on the event or
    /// `UpdateEventPayload` turn the draft back into the event. Blank details read back as empty text.
    init(editing event: SportEvent) {
        clientId = event.id
        title = event.title
        type = event.type
        startsAt = event.startsAt
        locationName = event.locationName
        coordinate = event.location.coordinate
        capacity = event.capacity ?? Self.proposedCapacity(for: event.participantCount)
        playerLimit = event.playerLimit
        description = event.description ?? ""
        lookingFor = event.lookingFor ?? ""
        skillLevel = event.skillLevel
        price = event.price?.amount
        group = event.group
    }

    /// What a draft is judged against beyond the backend's limits: a create keeps the app's lead-time margin, an
    /// edit only needs the future (the backend's rule) and never a cap below the people already in; a number needed
    /// is a target the host may set below them, and no limit has nothing to judge.
    struct Rules: Equatable, Sendable {
        let minimumLeadTime: TimeInterval
        let minimumCapacity: Int

        static let creation = Rules(minimumLeadTime: AppConfig.Events.Creation.minimumLeadTime,
                                    minimumCapacity: AppConfig.Events.Creation.capacityRange.lowerBound)

        static func editing(participantCount: Int) -> Rules {
            Rules(minimumLeadTime: AppConfig.Events.Editing.minimumLeadTime,
                  minimumCapacity: max(AppConfig.Events.Creation.capacityRange.lowerBound, participantCount))
        }

        /// The capacities the form's stepper offers under these rules: from the floor up for a cap, the backend's whole
        /// range otherwise.
        func capacityRange(for limit: PlayerLimit) -> ClosedRange<Int> {
            let limits = AppConfig.Events.Creation.capacityRange
            return limit == .maximum ? minimumCapacity...limits.upperBound : limits
        }
    }

    /// One reason a draft cannot be sent, in the order the form shows its fields.
    enum Issue: Hashable, Sendable {
        case titleMissing
        case titleTooLong
        case startsAtTooSoon
        case locationNameMissing
        case locationNameTooLong
        case coordinateMissing
        case capacityOutOfRange
        /// An edit asked for fewer spots than people already in the game.
        case capacityBelowParticipants
        case descriptionTooLong
        case lookingForTooLong
        case priceOutOfRange
    }

    /// The capacity as the wire and the stored event carry it: none without a limit.
    var capacityIfLimited: Int? { playerLimit.hasCapacity ? capacity : nil }
    var allowsExtraParticipants: Bool { playerLimit.allowsExtraParticipants }
    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedLocationName: String { locationName.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// `nil` when the host wrote nothing, so the payload omits the field.
    var trimmedDescription: String? { Self.optionalText(description) }
    var trimmedLookingFor: String? { Self.optionalText(lookingFor) }
    var isFree: Bool { (price ?? 0) <= 0 }

    /// The earliest start the form accepts, relative to `now`.
    static func earliestStart(now: Date, rules: Rules = .creation) -> Date {
        now.addingTimeInterval(rules.minimumLeadTime)
    }

    /// Everything that keeps the draft from being sent, in form order; empty means it can go.
    func issues(now: Date, rules: Rules = .creation) -> [Issue] {
        var issues = gameIssues(now: now, rules: rules)
        if let capacityIssue = capacityIssue(rules: rules) { issues.append(capacityIssue) }
        return issues + detailIssues()
    }

    /// The Game and Where sections: title, start, place and spot.
    private func gameIssues(now: Date, rules: Rules) -> [Issue] {
        var issues: [Issue] = []
        let limits = AppConfig.Events.Creation.self
        if trimmedTitle.isEmpty { issues.append(.titleMissing) }
        if trimmedTitle.wireLength > limits.titleMaxLength { issues.append(.titleTooLong) }
        if startsAt < Self.earliestStart(now: now, rules: rules) { issues.append(.startsAtTooSoon) }
        if trimmedLocationName.isEmpty { issues.append(.locationNameMissing) }
        if trimmedLocationName.wireLength > limits.locationNameMaxLength { issues.append(.locationNameTooLong) }
        if coordinate == nil { issues.append(.coordinateMissing) }
        return issues
    }

    /// Nothing without a limit. Outside the backend's range first; within it, a cap below the people already in (an
    /// edit's floor), which a number needed is free to be.
    private func capacityIssue(rules: Rules) -> Issue? {
        guard playerLimit.hasCapacity else { return nil }
        guard AppConfig.Events.Creation.capacityRange.contains(capacity) else { return .capacityOutOfRange }
        return playerLimit == .maximum && capacity < rules.minimumCapacity ? .capacityBelowParticipants : nil
    }

    /// The optional details.
    private func detailIssues() -> [Issue] {
        var issues: [Issue] = []
        let limits = AppConfig.Events.Creation.self
        if trimmedDescription.wireLength > limits.descriptionMaxLength { issues.append(.descriptionTooLong) }
        if trimmedLookingFor.wireLength > limits.lookingForMaxLength { issues.append(.lookingForTooLong) }
        if let price, !Self.isAcceptable(price: price) { issues.append(.priceOutOfRange) }
        return issues
    }

    func isValid(now: Date, rules: Rules = .creation) -> Bool {
        issues(now: now, rules: rules).isEmpty
    }

    /// The price the game carries on the wire and on its event: `nil` for a free game.
    func price(currencyCode: String = AppConfig.Events.marketCurrencyCode) -> Price? {
        guard !isFree, let price else { return nil }
        return Price(amount: price, currencyCode: currencyCode)
    }

    /// The event this draft becomes once stored: the caller hosts it and is its first participant. What the mock
    /// repository and the test fake answer for a create; the backend builds the same shape from the payload.
    func makeEvent(hostUserId: String?, hostName: String, coordinate: Coordinate) -> SportEvent {
        SportEvent(id: clientId,
                   title: trimmedTitle,
                   type: type,
                   startsAt: startsAt,
                   location: EventLocation(name: trimmedLocationName, coordinate: coordinate),
                   capacity: capacityIfLimited,
                   allowsExtraParticipants: allowsExtraParticipants,
                   participantCount: 1,
                   hostName: hostName,
                   hostUserId: hostUserId,
                   isJoined: true,
                   description: trimmedDescription,
                   lookingFor: trimmedLookingFor,
                   skillLevel: skillLevel,
                   price: price(),
                   group: group)
    }

    /// What the stepper shows for a game without a limit: the default, or the people already in when more than that
    /// are, so switching to a cap starts at the floor instead of below it; never past the backend's maximum.
    private static func proposedCapacity(for participantCount: Int) -> Int {
        let limits = AppConfig.Events.Creation.self
        return min(max(limits.defaultCapacity, participantCount), limits.capacityRange.upperBound)
    }

    /// Non-negative, below the backend's integer-digit limit and at most two decimals.
    private static func isAcceptable(price: Decimal) -> Bool {
        guard price >= 0, price < AppConfig.Events.Creation.priceLimitExclusive else { return false }
        var scaled = price * AppConfig.Events.Creation.priceMinorUnitsPerUnit
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return rounded == scaled
    }

    private static func optionalText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
