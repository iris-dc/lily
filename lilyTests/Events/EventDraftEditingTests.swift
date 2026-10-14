import Foundation
import Testing
@testable import lily

/// A host's game as a draft and back, and the rules an edit is judged by instead of a create's.
struct EventDraftEditingTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let kickers = EventGroupRef(id: "kickers", name: "Kreuzberg Kickers", visibility: .public, isDeleted: false)

    private static func makeEvent() -> SportEvent {
        SportEvent(id: "evt-1",
                   title: "Sunset 5-a-side",
                   type: .football,
                   startsAt: now.addingTimeInterval(3600),
                   location: EventLocation(name: "Riverside Pitch 2", coordinate: AppConfig.Location.mockCenter),
                   capacity: 10,
                   allowsExtraParticipants: true,
                   participantCount: 6,
                   hostName: "Marta",
                   hostUserId: "marta",
                   isJoined: true,
                   description: "Two halves",
                   lookingFor: nil,
                   skillLevel: .intermediate,
                   price: Price(amount: 5, currencyCode: "EUR"),
                   group: kickers)
    }

    @Test func aDraftOfAnEventCarriesEveryFieldAndTheEventsId() {
        let event = Self.makeEvent()

        let draft = EventDraft(editing: event)

        #expect(draft.clientId == event.id)
        #expect(draft.title == event.title && draft.type == event.type && draft.startsAt == event.startsAt)
        #expect(draft.locationName == event.locationName && draft.coordinate == event.location.coordinate)
        #expect(draft.capacity == event.capacity && draft.playerLimit == .minimum)
        #expect(draft.description == "Two halves" && draft.lookingFor.isEmpty)
        #expect(draft.skillLevel == .intermediate && draft.price == 5)
        #expect(draft.group == Self.kickers)
        #expect(draft.issues(now: Self.now, rules: .editing(participantCount: event.participantCount)).isEmpty)
    }

    /// A priced game is edited in its own currency, not the user's; a free one takes the user's for a price to come.
    @Test func theDraftKeepsThePricedGamesCurrencyAndTakesTheUsersForAFreeOne() {
        let priced = EventDraft(editing: Self.makeEvent(), currencyCode: "PLN")
        #expect(priced.currencyCode == "EUR")

        let free = EventDraft(editing: .fixture(), currencyCode: "PLN")
        #expect(free.currencyCode == "PLN" && free.eventPrice == nil)
    }

    /// The draft round-trips: an untouched draft rebuilds the event as it is, so "has changes" is a plain comparison.
    @Test func anUntouchedDraftRebuildsTheSameEvent() {
        let event = Self.makeEvent()

        #expect(event.updating(with: EventDraft(editing: event)) == event)
    }

    /// A game without a limit has no capacity to carry: the draft holds a number for the stepper (the default, or the
    /// people in when more than that are, so a cap starts at its floor), judges nothing about it, and hands none back.
    @Test func aGameWithoutALimitRoundTripsThroughAProposedCapacity() {
        let unlimited = SportEvent.fixture(capacity: nil,
                                           participants: 30,
                                           startsAt: Self.now.addingTimeInterval(3600),
                                           hostUserId: "marta",
                                           isJoined: true)
        var draft = EventDraft(editing: unlimited)

        #expect(draft.playerLimit == .unlimited && draft.capacity == 30)
        let few = EventDraft(editing: .fixture(capacity: nil, participants: 3))
        #expect(few.capacity == AppConfig.Events.Creation.defaultCapacity)
        #expect(draft.capacityIfLimited == nil && !draft.allowsExtraParticipants)
        #expect(unlimited.updating(with: draft) == unlimited)
        draft.capacity = 1
        #expect(draft.issues(now: Self.now, rules: .editing(participantCount: 30)).isEmpty, "an unsent number is not judged")
        draft.playerLimit = .maximum
        #expect(draft.issues(now: Self.now, rules: .editing(participantCount: 30)) == [.capacityOutOfRange])
        draft.capacity = 10
        #expect(draft.issues(now: Self.now, rules: .editing(participantCount: 30)) == [.capacityBelowParticipants],
                "capping below the people in is refused, as on the backend")
        #expect(unlimited.updating(with: draft).capacity == 10)
    }

    @Test func updatingTakesTheDraftsFieldsAndKeepsWhoIsInAndWhoHosts() {
        let event = Self.makeEvent()
        var draft = EventDraft(editing: event)
        draft.title = "  Late kick-off "
        draft.startsAt = Self.now.addingTimeInterval(7200)
        draft.capacity = 12
        draft.playerLimit = .maximum
        draft.description = "   "
        draft.lookingFor = "Two defenders"
        draft.skillLevel = nil
        draft.price = 0
        draft.coordinate = nil

        let updated = event.updating(with: draft)

        #expect(updated.id == event.id && updated.title == "Late kick-off")
        #expect(updated.startsAt == draft.startsAt && updated.capacity == 12 && !updated.allowsExtraParticipants)
        #expect(updated.description == nil && updated.lookingFor == "Two defenders")
        #expect(updated.skillLevel == nil && updated.price == nil)
        #expect(updated.location.coordinate == event.location.coordinate, "a draft without a spot keeps the event's")
        #expect(updated.participantCount == 6 && updated.isJoined == true)
        #expect(updated.hostUserId == "marta" && updated.hostName == "Marta" && updated.group == Self.kickers)
    }

    /// An edit needs only the request margin, not the create's quarter hour: a host fixing the place of a game about
    /// to start must not have to move it.
    @Test func anEditNeedsOnlyTheRequestMarginNotTheCreatesLeadTime() {
        var draft = EventDraft(editing: Self.makeEvent())
        let margin = AppConfig.Events.Editing.startMargin
        draft.startsAt = Self.now.addingTimeInterval(margin)
        let rules = EventDraft.Rules.editing(participantCount: 6)

        #expect(draft.issues(now: Self.now, rules: rules).isEmpty)
        #expect(draft.issues(now: Self.now) == [.startsAtTooSoon], "a create keeps its quarter hour")
        #expect(EventDraft.earliestStart(now: Self.now, rules: rules) == Self.now.addingTimeInterval(margin))
    }

    /// The margin covers the request's round trip and clock skew, so a start inside it is refused like one in the past.
    @Test func anEditWithinTheMarginIsStartsAtTooSoon() {
        var draft = EventDraft(editing: Self.makeEvent())
        let rules = EventDraft.Rules.editing(participantCount: 6)

        for offset in [AppConfig.Events.Editing.startMargin - 1, 0, -1] {
            draft.startsAt = Self.now.addingTimeInterval(offset)
            #expect(draft.issues(now: Self.now, rules: rules) == [.startsAtTooSoon], "\(offset) s ahead")
        }
    }

    /// A game that grew past the backend's maximum (a number needed, or no limit) still opens for editing: the
    /// stepper's floor stops at the maximum instead of inverting its range, and a cap is refused as below the people in.
    @Test func aGameWithMoreThan200PlayersOpensForEditing() {
        let limits = AppConfig.Events.Creation.capacityRange
        let crowd = limits.upperBound + 50
        let crowded = SportEvent.fixture(capacity: nil,
                                         participants: crowd,
                                         startsAt: Self.now.addingTimeInterval(3600),
                                         hostUserId: "marta",
                                         isJoined: true)
        var draft = EventDraft(editing: crowded)
        let rules = EventDraft.Rules.editing(participantCount: crowd)

        #expect(draft.playerLimit == .unlimited && draft.capacity == limits.upperBound)
        #expect(draft.issues(now: Self.now, rules: rules).isEmpty)
        #expect(rules.capacityRange(for: .maximum) == limits.upperBound...limits.upperBound)
        #expect(rules.capacityRange(for: .minimum) == limits)
        draft.playerLimit = .maximum
        #expect(draft.issues(now: Self.now, rules: rules) == [.capacityBelowParticipants], "never out of range")
        draft.playerLimit = .minimum
        #expect(draft.issues(now: Self.now, rules: rules).isEmpty)
    }

    /// The floor protects a cap. A draft that allows extras treats the capacity as a target and may set it below the
    /// people in, which is what the backend's condition allows too.
    @Test func editingRulesFloorTheCapacityAtThePeopleAlreadyInUnlessExtrasAreAllowed() {
        var draft = EventDraft(editing: Self.makeEvent())
        draft.playerLimit = .maximum
        let rules = EventDraft.Rules.editing(participantCount: 6)
        let limits = AppConfig.Events.Creation.capacityRange
        #expect(rules.capacityRange(for: .maximum) == 6...limits.upperBound)
        #expect(rules.capacityRange(for: .minimum) == limits && rules.capacityRange(for: .unlimited) == limits)
        #expect(EventDraft.Rules.editing(participantCount: 1).capacityRange(for: .maximum) == limits,
                "the host alone never lowers the floor below the backend's minimum")

        draft.capacity = 5
        #expect(draft.issues(now: Self.now, rules: rules) == [.capacityBelowParticipants])
        #expect(draft.issues(now: Self.now).isEmpty, "a create has no participants to protect")
        draft.playerLimit = .minimum
        #expect(draft.issues(now: Self.now, rules: rules).isEmpty, "needing fewer than are in is fine when more may join")
        draft.capacity = 1
        #expect(draft.issues(now: Self.now, rules: rules) == [.capacityOutOfRange], "outside the range comes first")
    }

    @Test func everyIssueHasCopy() {
        let issues: [EventDraft.Issue] = [
            .titleMissing, .titleTooLong, .startsAtTooSoon, .locationNameMissing, .locationNameTooLong, .coordinateMissing,
            .capacityOutOfRange, .capacityBelowParticipants, .descriptionTooLong, .lookingForTooLong, .priceUnreadable,
            .priceOutOfRange,
        ]
        for issue in issues {
            #expect(!AppBranding.Events.Create.message(for: issue).isEmpty, "\(issue)")
        }
    }
}
