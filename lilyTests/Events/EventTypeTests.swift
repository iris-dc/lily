import Foundation
import Testing
import UIKit
@testable import lily

/// The event type on the wire: the known names round-trip in the backend's snake_case, and a type this build does not
/// know is kept by name, drawn as Other, never offered and re-encoded as it came, so an event, group, tournament,
/// profile or invite from a newer backend still decodes.
struct EventTypeTests {
    private static let golf = EventType.unknown("golf")

    @Test func multiWordTypesTravelInTheBackendsSnakeCase() {
        #expect(EventType.tableTennis.wireName == "table_tennis")
        #expect(EventType.martialArts.wireName == "martial_arts")
        #expect(EventType.boardGames.wireName == "board_games")
        #expect(EventType(wireName: "esports") == .esports && EventType(wireName: "travel") == .travel)
    }

    @Test func everyTypeHasASymbolTheSystemKnows() {
        for type in EventType.known {
            #expect(UIImage(systemName: type.symbolName) != nil, "\(type.wireName): \(type.symbolName)")
        }
        #expect(UIImage(systemName: Self.golf.symbolName) != nil)
    }

    @Test func everyTypeNamesItselfOnceAndOtherComesLast() {
        let names = EventType.known.map(\.displayName)
        #expect(Set(names).count == names.count)
        #expect(Set(EventType.known.map(\.wireName)).count == EventType.known.count, "the lookup by wire name needs unique names")
        #expect(EventType.known.last == .other)
        #expect(EventType.esports.displayName == "Esports" && EventType.tableTennis.displayName == "Table tennis")
    }

    @Test func anUnknownEventTypeDecodesByNameAndReEncodesAsItCame() throws {
        let decoded = try JSONDecoder().decode([EventType].self, from: Data(#"["golf"]"#.utf8))
        #expect(decoded == [Self.golf] && decoded[0].isUnknown && decoded[0].wireName == "golf")
        #expect(String(bytes: try JSONEncoder().encode(decoded), encoding: .utf8) == #"["golf"]"#)

        let event = try ContractSamples.decode(SportEvent.self, from: golfed(ContractSamples.event))
        #expect(event.type == Self.golf)
        #expect(event.id == "evt_01J" && event.title == "Sunset 5-a-side" && event.skillLevel == .intermediate)
        let json = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(event), encoding: .utf8))
        #expect(json.contains(#""type":"golf""#))
        #expect(try ContractSamples.decode(SportEvent.self, from: json) == event)
    }

    @Test func groupsTournamentsProfilesAndInvitesTolerateAnUnknownTypeToo() throws {
        let group = try ContractSamples.decode(SportGroup.self, from: golfed(ContractSamples.group))
        let tournament = try ContractSamples.decode(Tournament.self, from: golfed(ContractSamples.tournament))
        let profile = try ContractSamples.decode(UserProfile.self, from: golfed(ContractSamples.userProfile))
        let item = try ContractSamples.decode(InboxItem.self, from: golfed(LaurelTournamentInboxJSON.tournamentInvite))

        #expect(group.type == Self.golf && tournament.type == Self.golf)
        #expect(profile.sharedGroups.first?.type == Self.golf)
        #expect(item.tournamentInvite?.type == Self.golf)
    }

    /// Display only: the type reads and draws as Other, yet no chip or picker ever lists it.
    @Test func anUnknownTypeDrawsAsOtherAndIsNeverOffered() {
        #expect(Self.golf.displayName == EventType.other.displayName)
        #expect(Self.golf.symbolName == EventType.other.symbolName)
        #expect(!EventType.known.contains { $0.isUnknown })
        #expect(EventType.known.contains(.tennis) && EventType.known.contains(.yoga),
                "a type is never hidden because no loaded game has it")
        #expect(EventType.known.last == .other)
    }

    /// `sample` with its football type swapped for one this build does not know; a sample without that type is a failure.
    private func golfed(_ sample: String) throws -> String {
        let golfed = sample.replacingOccurrences(of: #""type":"football""#, with: #""type":"golf""#)
        try #require(golfed != sample)
        return golfed
    }
}
