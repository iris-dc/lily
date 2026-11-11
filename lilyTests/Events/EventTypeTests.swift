import Foundation
import Testing
import UIKit
@testable import lily

/// The event type on the wire: the known names round-trip in the backend's snake_case, and a type this build does not
/// know is kept by name, drawn as Other, never offered and re-encoded as it came, so an event, group, tournament,
/// profile or invite from a newer backend still decodes.
struct EventTypeTests {
    /// A name no build knows (golf stopped qualifying on 2026-11-11, when it joined the known types).
    private static let cricket = EventType.unknown("cricket")

    @Test func multiWordTypesTravelInTheBackendsSnakeCase() {
        #expect(EventType.tableTennis.wireName == "table_tennis")
        #expect(EventType.martialArts.wireName == "martial_arts")
        #expect(EventType.boardGames.wireName == "board_games")
        #expect(EventType(wireName: "esports") == .esports && EventType(wireName: "travel") == .travel)
    }

    /// The 2026-11-11 additions are known types now, not names to tolerate; Laurel's enum grew the same list.
    @Test func theNewTypesAreKnownByTheirWireNames() {
        #expect(EventType(wireName: "golf") == .golf && EventType(wireName: "squash") == .squash)
        #expect(EventType(wireName: "pickleball") == .pickleball && EventType(wireName: "hockey") == .hockey)
        #expect(EventType(wireName: "skateboarding") == .skateboarding && EventType(wireName: "chess") == .chess)
        #expect(EventType.known.count == 34)
    }

    @Test func everyTypeHasASymbolTheSystemKnows() {
        for type in EventType.known {
            #expect(UIImage(systemName: type.symbolName) != nil, "\(type.wireName): \(type.symbolName)")
        }
        #expect(UIImage(systemName: Self.cricket.symbolName) != nil)
    }

    @Test func everyTypeNamesItselfOnceAndOtherComesLast() {
        let names = EventType.known.map(\.displayName)
        #expect(Set(names).count == names.count)
        #expect(Set(EventType.known.map(\.wireName)).count == EventType.known.count, "the lookup by wire name needs unique names")
        #expect(EventType.known.last == .other)
        #expect(EventType.esports.displayName == "Esports" && EventType.tableTennis.displayName == "Table tennis")
    }

    @Test func anUnknownEventTypeDecodesByNameAndReEncodesAsItCame() throws {
        let decoded = try JSONDecoder().decode([EventType].self, from: Data(#"["cricket"]"#.utf8))
        #expect(decoded == [Self.cricket] && decoded[0].isUnknown && decoded[0].wireName == "cricket")
        #expect(String(bytes: try JSONEncoder().encode(decoded), encoding: .utf8) == #"["cricket"]"#)

        let event = try ContractSamples.decode(SportEvent.self, from: withUnknownType(ContractSamples.event))
        #expect(event.type == Self.cricket)
        #expect(event.id == "evt_01J" && event.title == "Sunset 5-a-side" && event.skillLevel == .intermediate)
        let json = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(event), encoding: .utf8))
        #expect(json.contains(#""type":"cricket""#))
        #expect(try ContractSamples.decode(SportEvent.self, from: json) == event)
    }

    @Test func groupsTournamentsProfilesAndInvitesTolerateAnUnknownTypeToo() throws {
        let group = try ContractSamples.decode(SportGroup.self, from: withUnknownType(ContractSamples.group))
        let tournament = try ContractSamples.decode(Tournament.self, from: withUnknownType(ContractSamples.tournament))
        let profile = try ContractSamples.decode(UserProfile.self, from: withUnknownType(ContractSamples.userProfile))
        let item = try ContractSamples.decode(InboxItem.self, from: withUnknownType(ContractSamples.tournamentInvite))

        #expect(group.type == Self.cricket && tournament.type == Self.cricket)
        #expect(profile.sharedGroups.first?.type == Self.cricket)
        #expect(item.tournamentInvite?.type == Self.cricket)
    }

    /// Display only: the type reads and draws as Other, yet no chip or picker ever lists it.
    @Test func anUnknownTypeDrawsAsOtherAndIsNeverOffered() {
        #expect(Self.cricket.displayName == EventType.other.displayName)
        #expect(Self.cricket.symbolName == EventType.other.symbolName)
        #expect(!EventType.known.contains { $0.isUnknown })
        #expect(EventType.known.contains(.tennis) && EventType.known.contains(.yoga),
                "a type is never hidden because no loaded game has it")
        #expect(EventType.known.last == .other)
    }

    /// `sample` with its football type swapped for one this build does not know; a sample without that type is a failure.
    private func withUnknownType(_ sample: String) throws -> String {
        let swapped = sample.replacingOccurrences(of: #""type":"football""#, with: #""type":"cricket""#)
        try #require(swapped != sample)
        return swapped
    }
}
