import Foundation
import Testing
@testable import lily

/// The deletion contract's additive `deleted` flag on its four wire representations, and the one helper mapping it.
struct TombstoneTests {
    @Test func theFlagMapsToTheLocalizedNameAndTheFixedMark() {
        #expect(Tombstone.displayName("Player", deleted: true) == AppBranding.DeletedUser.name)
        #expect(Tombstone.displayName("Marta", deleted: nil) == "Marta", "an old backend omits the flag")
        #expect(Tombstone.displayName("Marta", deleted: false) == "Marta")
        #expect(Tombstone.symbol == DesignTokens.Symbols.deletedUser)
    }

    @Test func theFourWireFlagsDecodeWhereTheContractPlacesThem() throws {
        let message = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.message
            .replacingOccurrences(of: #""senderName":"Marta""#, with: #""senderName":"Player","deleted":true"#))
        #expect(message.deleted == true && !message.isDeleted, "the sender's tombstone, not the message's own deletion")

        let event = try ContractSamples.decode(SportEvent.self, from: ContractSamples.event
            .replacingOccurrences(of: #""hostName":"Marta""#, with: #""hostName":"Player","deleted":true"#))
        #expect(event.deleted == true)

        let tournament = try ContractSamples.decode(Tournament.self, from: ContractSamples.tournament
            .replacingOccurrences(of: #""organizerName":"Apple Tester""#, with: #""organizerName":"Player","deleted":true"#))
        #expect(tournament.deleted == true)

        let entry = try ContractSamples.decode(TournamentEntry.self, from: ContractSamples.entry
            .replacingOccurrences(of: #""displayName":"Marta""#, with: #""displayName":"Player","deleted":true"#))
        #expect(entry.members.first?.deleted == true)
        #expect(entry.members.last?.deleted == nil, "only the deleted member is flagged")
    }

    @Test func anAbsentFlagReadsAsNotDeletedAndStaysOffTheWire() throws {
        let message = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.message)
        let event = try ContractSamples.decode(SportEvent.self, from: ContractSamples.event)
        let tournament = try ContractSamples.decode(Tournament.self, from: ContractSamples.tournament)
        let entry = try ContractSamples.decode(TournamentEntry.self, from: ContractSamples.entry)
        #expect(message.deleted == nil && event.deleted == nil && tournament.deleted == nil)
        #expect(entry.members.allSatisfy { $0.deleted == nil })

        let encoded = try #require(String(bytes: APIJSONCoding.makeEncoder().encode(event), encoding: .utf8))
        #expect(!encoded.contains(#""deleted""#), "an absent optional is omitted, never null or false")
    }

    @Test func theFlagSurvivesTheAppsOwnRoundTrip() throws {
        let stamped = try ContractSamples.decode(SportEvent.self, from: ContractSamples.event
            .replacingOccurrences(of: #""hostName":"Marta""#, with: #""hostName":"Player","deleted":true"#))
        let decoded = try APIJSONCoding.makeDecoder().decode(SportEvent.self,
                                                             from: APIJSONCoding.makeEncoder().encode(stamped))
        #expect(decoded.deleted == true)
    }
}
