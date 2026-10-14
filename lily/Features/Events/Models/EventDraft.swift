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
    /// What the host typed into the price field, per person, the one source: `price` reads it as an amount. Empty
    /// means free.
    var priceText = ""
    /// The locale the price is typed in and an edit is seeded in, so the text and its amount always agree: the app's
    /// locale when the draft was made, like `currencyCode`.
    let locale: Locale
    /// The currency `price` is typed in: the user's preferred one for a new game, the game's own for an edit.
    let currencyCode: String
    /// The group to host the game in; `nil` for a game of its own. The ref, not a bare id, so the stored event can
    /// show its badge without a second lookup.
    var group: EventGroupRef?

    init(startsAt: Date,
         currencyCode: String,
         locale: Locale = AppLocale.locale,
         clientId: String = UUID().uuidString.lowercased()) {
        self.clientId = clientId
        self.startsAt = startsAt
        self.currencyCode = currencyCode
        self.locale = locale
    }

    /// The event as a draft, for the host's edit: `clientId` is the event's id, and `updating(with:)` on the event or
    /// `UpdateEventPayload` turn the draft back into the event. Blank details read back as empty text. A priced game
    /// keeps its currency; a free one takes `currencyCode` (the user's) should the host add a price. The price is
    /// seeded as the field shows it, in `locale`.
    init(editing event: SportEvent, currencyCode: String, locale: Locale = AppLocale.locale) {
        self.locale = locale
        clientId = event.id
        self.currencyCode = event.price?.currencyCode ?? currencyCode
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
        group = event.group
        price = event.price?.amount
    }

    /// What a draft is judged against beyond the backend's limits: a create keeps the app's lead-time margin, an
    /// edit the request margin (the backend requires only the future) and never a cap below the people already in; a
    /// number needed is a target the host may set below them, and no limit has nothing to judge.
    struct Rules: Equatable, Sendable {
        let minimumLeadTime: TimeInterval
        let minimumCapacity: Int

        static let creation = Rules(minimumLeadTime: AppConfig.Events.Creation.minimumLeadTime,
                                    minimumCapacity: AppConfig.Events.Creation.capacityRange.lowerBound)

        /// The floor is the people in, unclamped: a cap of 200 under 250 people is `.capacityBelowParticipants`, the
        /// backend's `CAPACITY_FLOOR`.
        static func editing(participantCount: Int) -> Rules {
            Rules(minimumLeadTime: AppConfig.Events.Editing.startMargin,
                  minimumCapacity: max(AppConfig.Events.Creation.capacityRange.lowerBound, participantCount))
        }

        /// The capacities the form's stepper offers under these rules: from the floor up for a cap, the backend's whole
        /// range otherwise. The floor never passes the backend's maximum, so a game that grew past it (a number needed
        /// or no limit with 250 in) still opens for editing; the stepper then offers 200...200 and the hint says why no
        /// cap can be set.
        func capacityRange(for limit: PlayerLimit) -> ClosedRange<Int> {
            let limits = AppConfig.Events.Creation.capacityRange
            let floor = min(minimumCapacity, limits.upperBound)
            return limit == .maximum ? floor...limits.upperBound : limits
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
        /// Text in the price field that is not a number (a symbol, a code, a stray or foreign separator); it holds
        /// Create instead of making the game free or misreading the amount.
        case priceUnreadable
        case priceOutOfRange
    }

    /// The capacity as the wire and the stored event carry it: none without a limit.
    var capacityIfLimited: Int? { playerLimit.hasCapacity ? capacity : nil }
    var allowsExtraParticipants: Bool { playerLimit.allowsExtraParticipants }
    var trimmedTitle: String { title.trimmed }
    /// The Where section as the shared rule judges it: the name typed and the spot picked.
    var place: PlaceDraft { PlaceDraft(name: locationName, coordinate: coordinate) }
    var trimmedLocationName: String { place.trimmedName }
    /// `nil` when the host wrote nothing, so the payload omits the field.
    var trimmedDescription: String? { description.nonBlankTrimmed }
    var trimmedLookingFor: String? { lookingFor.nonBlankTrimmed }
    var isFree: Bool { (price ?? 0) <= 0 }
    /// Something typed that the parser cannot read in the draft's locale; blank is empty, not unreadable.
    var hasUnreadablePrice: Bool { price == nil && !priceText.trimmed.isEmpty }

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
        issues += place.issues(maxLength: limits.locationNameMaxLength).map(Issue.init)
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
        if hasUnreadablePrice {
            issues.append(.priceUnreadable)
        } else if let price, !Self.isAcceptable(price: price) {
            issues.append(.priceOutOfRange)
        }
        return issues
    }

    func isValid(now: Date, rules: Rules = .creation) -> Bool {
        issues(now: now, rules: rules).isEmpty
    }

    /// The typed text as an amount, `nil` for an empty or unreadable text. Setting an amount types it as the field
    /// would show it (at most two decimals), in the draft's locale, so it reads back unchanged.
    var price: Decimal? {
        get { Price.parseAmount(priceText, locale: locale) }
        set { priceText = newValue.map { Price.inputText($0, locale: locale) } ?? "" }
    }

    /// The price the game carries on the wire and on its event, in the draft's currency: `nil` for a free game. Not
    /// `price`, which is the typed amount.
    var eventPrice: Price? {
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
                   location: place.location(at: coordinate),
                   capacity: capacityIfLimited,
                   allowsExtraParticipants: allowsExtraParticipants,
                   participantCount: 1,
                   hostName: hostName,
                   hostUserId: hostUserId,
                   isJoined: true,
                   description: trimmedDescription,
                   lookingFor: trimmedLookingFor,
                   skillLevel: skillLevel,
                   price: eventPrice,
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
}

nonisolated extension EventDraft.Issue {
    /// The shared place issue under the name this form's Where section reports it by.
    fileprivate init(_ place: PlaceDraft.Issue) {
        switch place {
        case .nameMissing: self = .locationNameMissing
        case .nameTooLong: self = .locationNameTooLong
        case .coordinateMissing: self = .coordinateMissing
        }
    }
}
