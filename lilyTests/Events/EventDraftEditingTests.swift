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
        #expect(draft.capacity == event.capacity)
        #expect(draft.description == "Two halves" && draft.lookingFor.isEmpty)
        #expect(draft.skillLevel == .intermediate && draft.price == 5)
        #expect(draft.group == Self.kickers)
        #expect(draft.issues(now: Self.now, rules: .editing(participantCount: event.participantCount)).isEmpty)
    }

    /// The draft round-trips: an untouched draft rebuilds the event as it is, so "has changes" is a plain comparison.
    @Test func anUntouchedDraftRebuildsTheSameEvent() {
        let event = Self.makeEvent()

        #expect(event.updating(with: EventDraft(editing: event)) == event)
    }

    @Test func updatingTakesTheDraftsFieldsAndKeepsWhoIsInAndWhoHosts() {
        let event = Self.makeEvent()
        var draft = EventDraft(editing: event)
        draft.title = "  Late kick-off "
        draft.startsAt = Self.now.addingTimeInterval(7200)
        draft.capacity = 12
        draft.description = "   "
        draft.lookingFor = "Two defenders"
        draft.skillLevel = nil
        draft.price = 0
        draft.coordinate = nil

        let updated = event.updating(with: draft)

        #expect(updated.id == event.id && updated.title == "Late kick-off")
        #expect(updated.startsAt == draft.startsAt && updated.capacity == 12)
        #expect(updated.description == nil && updated.lookingFor == "Two defenders")
        #expect(updated.skillLevel == nil && updated.price == nil)
        #expect(updated.location.coordinate == event.location.coordinate, "a draft without a spot keeps the event's")
        #expect(updated.participantCount == 6 && updated.isJoined == true)
        #expect(updated.hostUserId == "marta" && updated.hostName == "Marta" && updated.group == Self.kickers)
    }

    /// An edit only needs the future: a host fixing the place of a game about to start must not have to move it.
    @Test func editingRulesNeedNoLeadTime() {
        var draft = EventDraft(editing: Self.makeEvent())
        draft.startsAt = Self.now.addingTimeInterval(60)
        let rules = EventDraft.Rules.editing(participantCount: 6)

        #expect(draft.issues(now: Self.now, rules: rules).isEmpty)
        #expect(draft.issues(now: Self.now) == [.startsAtTooSoon], "a create keeps its margin")
        #expect(EventDraft.earliestStart(now: Self.now, rules: rules) == Self.now)
        draft.startsAt = Self.now.addingTimeInterval(-1)
        #expect(draft.issues(now: Self.now, rules: rules) == [.startsAtTooSoon])
    }

    @Test func editingRulesFloorTheCapacityAtThePeopleAlreadyIn() {
        var draft = EventDraft(editing: Self.makeEvent())
        let rules = EventDraft.Rules.editing(participantCount: 6)
        #expect(rules.capacityRange == 6...AppConfig.Events.Creation.capacityRange.upperBound)
        #expect(EventDraft.Rules.editing(participantCount: 1).capacityRange == AppConfig.Events.Creation.capacityRange,
                "the host alone never lowers the floor below the backend's minimum")

        draft.capacity = 5
        #expect(draft.issues(now: Self.now, rules: rules) == [.capacityBelowParticipants])
        #expect(draft.issues(now: Self.now).isEmpty, "a create has no participants to protect")
        draft.capacity = 1
        #expect(draft.issues(now: Self.now, rules: rules) == [.capacityOutOfRange], "outside the range comes first")
    }

    @Test func everyIssueHasCopy() {
        let issues: [EventDraft.Issue] = [
            .titleMissing, .titleTooLong, .startsAtTooSoon, .locationNameMissing, .locationNameTooLong, .coordinateMissing,
            .capacityOutOfRange, .capacityBelowParticipants, .descriptionTooLong, .lookingForTooLong, .priceOutOfRange,
        ]
        for issue in issues {
            #expect(!AppBranding.Events.Create.message(for: issue).isEmpty, "\(issue)")
        }
    }
}
