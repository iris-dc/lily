import Foundation
import Testing
@testable import lily

/// What keeps a draft from being sent, judged at the boundaries of `AppConfig.Events.Creation`.
struct EventDraftTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let limits = AppConfig.Events.Creation.self

    /// One change that breaks a valid draft so that exactly the named issue shows.
    struct Breakage: CustomTestStringConvertible {
        let issue: EventDraft.Issue
        let apply: @Sendable (inout EventDraft) -> Void

        var testDescription: String { "\(issue)" }
    }

    private static let breakages: [Breakage] = [
        Breakage(issue: .titleMissing) { $0.title = " \n" },
        Breakage(issue: .titleTooLong) { $0.title = text(limits.titleMaxLength + 1) },
        Breakage(issue: .startsAtTooSoon) { $0.startsAt = EventDraft.earliestStart(now: now).addingTimeInterval(-1) },
        Breakage(issue: .locationNameMissing) { $0.locationName = "" },
        Breakage(issue: .locationNameTooLong) { $0.locationName = text(limits.locationNameMaxLength + 1) },
        Breakage(issue: .coordinateMissing) { $0.coordinate = nil },
        Breakage(issue: .capacityOutOfRange) { $0.capacity = limits.capacityRange.upperBound + 1 },
        Breakage(issue: .descriptionTooLong) { $0.description = text(limits.descriptionMaxLength + 1) },
        Breakage(issue: .lookingForTooLong) { $0.lookingFor = text(limits.lookingForMaxLength + 1) },
        Breakage(issue: .priceOutOfRange) { $0.price = Decimal(string: "0.001") },
    ]

    /// The backend takes at most seven integer digits and two decimals; zero and nothing both mean free.
    private static let acceptedPrices: [String?] = [nil, "0", "5", "7.5", "12.99", "9999999.99"]
    private static let refusedPrices = ["0.001", "10000000", "-1"]

    private static func makeValidDraft() -> EventDraft {
        .fixture(now: now)
    }

    private static func text(_ count: Int) -> String {
        String(repeating: "x", count: count)
    }

    private func issues(of draft: EventDraft) -> [EventDraft.Issue] {
        draft.issues(now: Self.now)
    }

    @Test func aNewDraftHasTheDefaultsAndAsksForTheRequiredFields() {
        let draft = EventDraft(startsAt: Self.now.addingTimeInterval(Self.limits.defaultStartOffset))

        #expect(draft.title.isEmpty && draft.locationName.isEmpty && draft.coordinate == nil)
        #expect(draft.type == .football)
        #expect(draft.capacity == Self.limits.defaultCapacity && draft.playerLimit == .maximum)
        #expect(draft.skillLevel == nil && draft.price == nil && draft.isFree)
        #expect(issues(of: draft) == [.titleMissing, .locationNameMissing, .coordinateMissing])
        #expect(!draft.isValid(now: Self.now))
    }

    /// The id is what lets a repeated create find its event: unique per draft, never changed after, and lower-case
    /// like the id the backend stores, so the mock and the real answer carry the same id.
    @Test func everyDraftGetsItsOwnLowerCaseClientId() {
        let first = EventDraft(startsAt: Self.now)
        let second = EventDraft(startsAt: Self.now)

        #expect(first.clientId != second.clientId)
        #expect(UUID(uuidString: first.clientId) != nil)
        #expect(first.clientId == first.clientId.lowercased())
        #expect(TestFixtures.isBackendEventId(first.clientId))
        #expect(EventDraft(startsAt: Self.now, clientId: "given").clientId == "given")
    }

    /// Laurel's `@Size` counts UTF-16 units (Java's `String.length()`), so an emoji counts two here as well; counting
    /// characters would enable Create for a title the backend then refuses.
    @Test func lengthsAreCountedInUTF16UnitsLikeTheBackend() {
        let emoji = "😀"
        #expect(emoji.count == 1 && emoji.utf16.count == 2)
        var draft = Self.makeValidDraft()

        draft.title = String(repeating: emoji, count: Self.limits.titleMaxLength / 2)
        #expect(issues(of: draft).isEmpty)

        draft.title = String(repeating: emoji, count: Self.limits.titleMaxLength / 2 + 1)
        #expect(issues(of: draft) == [.titleTooLong])

        draft.title = "x"
        draft.locationName = String(repeating: emoji, count: Self.limits.locationNameMaxLength / 2 + 1)
        draft.description = String(repeating: emoji, count: Self.limits.descriptionMaxLength / 2 + 1)
        draft.lookingFor = String(repeating: emoji, count: Self.limits.lookingForMaxLength / 2 + 1)
        #expect(issues(of: draft) == [.locationNameTooLong, .descriptionTooLong, .lookingForTooLong])
    }

    /// One place turns a draft's amount into a `Price`: free (nothing or zero) is no price at all.
    @Test func thePriceIsAbsentForAFreeGameAndCarriesTheCurrencyOtherwise() {
        var draft = Self.makeValidDraft()
        #expect(draft.price() == nil)

        draft.price = 0
        #expect(draft.price() == nil)

        draft.price = 5
        #expect(draft.price() == Price(amount: 5, currencyCode: AppConfig.Events.marketCurrencyCode))
        #expect(draft.price(currencyCode: "USD") == Price(amount: 5, currencyCode: "USD"))
    }

    /// What the mock repository and the test fake answer for a create: the draft as a stored event, hosted and joined
    /// by the caller, who is its first participant, with trimmed texts and blank details absent.
    @Test func makeEventIsHostedAndJoinedByTheCallerWithTheDraftsDetails() {
        var draft = Self.makeValidDraft()
        draft.title = " Sunset 5-a-side "
        draft.description = " Two halves "
        draft.lookingFor = "   "
        draft.skillLevel = .advanced
        draft.price = Decimal(string: "7.5")
        let spot = Coordinate(latitude: 48.8566, longitude: 2.3522)

        let event = draft.makeEvent(hostUserId: "u-1", hostName: "Jo", coordinate: spot)

        #expect(event.id == draft.clientId && event.title == "Sunset 5-a-side")
        #expect(event.type == draft.type && event.startsAt == draft.startsAt && event.capacity == draft.capacity)
        #expect(event.location == EventLocation(name: "Test Park", coordinate: spot))
        #expect(event.hostUserId == "u-1" && event.hostName == "Jo")
        #expect(event.participates && event.participantCount == 1)
        #expect(Participation(event: event, userID: "u-1") == .hosting)
        #expect(event.description == "Two halves" && event.lookingFor == nil && event.skillLevel == .advanced)
        #expect(event.price == draft.price())
        #expect(event.group == nil)
    }

    /// The group is the ref, not a bare id, so the stored event shows its badge without a lookup.
    @Test func makeEventCarriesTheDraftsGroup() {
        var draft = Self.makeValidDraft()
        let kickers = EventGroupRef(id: "kickers", name: "Kreuzberg Kickers", visibility: .public, isDeleted: false)
        draft.group = kickers

        let event = draft.makeEvent(hostUserId: "u-1", hostName: "Jo", coordinate: AppConfig.Location.mockCenter)

        #expect(event.group == kickers)
        #expect(issues(of: draft).isEmpty, "the group is never a validation matter on the device")
    }

    @Test func aCompleteDraftIsValid() {
        let draft = Self.makeValidDraft()

        #expect(issues(of: draft).isEmpty)
        #expect(draft.isValid(now: Self.now))
    }

    @Test(arguments: breakages)
    func eachIssueTriggersAlone(breakage: Breakage) {
        var draft = Self.makeValidDraft()

        breakage.apply(&draft)

        #expect(issues(of: draft) == [breakage.issue])
    }

    /// Surrounding whitespace neither counts against a limit nor makes a blank field non-blank.
    @Test func textsAreTrimmedBeforeTheyAreJudged() {
        var draft = Self.makeValidDraft()
        draft.title = "  " + Self.text(Self.limits.titleMaxLength) + "\n"
        draft.locationName = " " + Self.text(Self.limits.locationNameMaxLength) + " "
        draft.description = "  Bring both colours  "
        draft.lookingFor = "   "

        #expect(issues(of: draft).isEmpty)
        #expect(draft.trimmedTitle.count == Self.limits.titleMaxLength)
        #expect(draft.trimmedLocationName.count == Self.limits.locationNameMaxLength)
        #expect(draft.trimmedDescription == "Bring both colours")
        #expect(draft.trimmedLookingFor == nil)
    }

    @Test func optionalTextsAreAcceptedUpToTheirLimit() {
        var draft = Self.makeValidDraft()
        draft.description = Self.text(Self.limits.descriptionMaxLength)
        draft.lookingFor = Self.text(Self.limits.lookingForMaxLength)

        #expect(issues(of: draft).isEmpty)
        #expect(draft.trimmedDescription?.count == Self.limits.descriptionMaxLength)
        #expect(draft.trimmedLookingFor?.count == Self.limits.lookingForMaxLength)
    }

    @Test func theStartMayBeExactlyTheLeadTimeAhead() {
        let earliest = EventDraft.earliestStart(now: Self.now)
        #expect(earliest == Self.now.addingTimeInterval(Self.limits.minimumLeadTime))
        var draft = Self.makeValidDraft()

        draft.startsAt = earliest
        #expect(issues(of: draft).isEmpty)

        draft.startsAt = earliest.addingTimeInterval(-1)
        #expect(issues(of: draft) == [.startsAtTooSoon])
    }

    @Test func capacityIsAcceptedAtBothEndsOfTheRangeAndRefusedBeyond() {
        let range = Self.limits.capacityRange
        var draft = Self.makeValidDraft()

        for capacity in [range.lowerBound, range.upperBound] {
            draft.capacity = capacity
            #expect(issues(of: draft).isEmpty, "\(capacity)")
        }
        for capacity in [range.lowerBound - 1, range.upperBound + 1] {
            draft.capacity = capacity
            #expect(issues(of: draft) == [.capacityOutOfRange], "\(capacity)")
        }
    }

    @Test(arguments: acceptedPrices)
    func pricesWithinTheLimitsPass(text: String?) {
        var draft = Self.makeValidDraft()

        draft.price = text.flatMap { Decimal(string: $0) }

        #expect(issues(of: draft).isEmpty)
    }

    @Test(arguments: refusedPrices)
    func pricesBeyondTheLimitsAreRefused(text: String) {
        var draft = Self.makeValidDraft()

        draft.price = Decimal(string: text)

        #expect(issues(of: draft) == [.priceOutOfRange])
    }

    @Test func zeroOrNoPriceMeansFree() {
        var draft = Self.makeValidDraft()
        #expect(draft.isFree)

        draft.price = 0
        #expect(draft.isFree)

        draft.price = 5
        #expect(!draft.isFree)
    }

    /// Issues come in the order the form shows its fields, so the first one is the one nearest the top.
    @Test func issuesFollowTheFormOrder() {
        var draft = EventDraft(startsAt: Self.now)
        draft.capacity = Self.limits.capacityRange.lowerBound - 1
        draft.description = Self.text(Self.limits.descriptionMaxLength + 1)
        draft.lookingFor = Self.text(Self.limits.lookingForMaxLength + 1)
        draft.price = -1

        #expect(issues(of: draft) == [
            .titleMissing, .startsAtTooSoon, .locationNameMissing, .coordinateMissing,
            .capacityOutOfRange, .descriptionTooLong, .lookingForTooLong, .priceOutOfRange,
        ])
    }
}
