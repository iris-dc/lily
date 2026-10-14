import Foundation
import Testing
@testable import lily

/// The skill level on the wire: the known names round-trip, only they are offered, and a level this build does not
/// know is kept by name, reads as any level and re-encodes as it came, so an event from a newer backend still decodes.
struct SkillLevelTests {
    private static let pro = SkillLevel.unknown("pro")

    @Test func knownLevelsRoundTripThroughTheirWireNames() throws {
        #expect(SkillLevel(wireName: "beginner") == .beginner)
        #expect(SkillLevel(wireName: "intermediate") == .intermediate)
        #expect(SkillLevel.advanced.wireName == "advanced")

        let json = try JSONEncoder().encode([SkillLevel.beginner, .advanced])
        #expect(String(bytes: json, encoding: .utf8) == #"["beginner","advanced"]"#)
        #expect(try JSONDecoder().decode([SkillLevel].self, from: json) == [.beginner, .advanced])
    }

    @Test func onlyTheKnownLevelsAreOffered() {
        #expect(SkillLevel.known == [.beginner, .intermediate, .advanced])
        #expect(!SkillLevel.known.contains { $0.isUnknown })
    }

    @Test func anUnknownLevelDecodesByNameReadsAsAnyLevelAndEncodesAsItCame() throws {
        let decoded = try JSONDecoder().decode([SkillLevel].self, from: Data(#"["pro"]"#.utf8))
        #expect(decoded == [Self.pro] && decoded[0].isUnknown && decoded[0].wireName == "pro")
        #expect(decoded[0].displayName == AppBranding.Events.anyLevel)
        #expect(decoded[0].ifKnown == nil && SkillLevel.advanced.ifKnown == .advanced, "an unknown level counts as none")
        #expect(String(bytes: try JSONEncoder().encode(decoded), encoding: .utf8) == #"["pro"]"#)
    }

    @Test func anEventWithAnUnknownSkillLevelStillDecodes() throws {
        let sample = ContractSamples.event.replacingOccurrences(of: #""skillLevel":"intermediate""#,
                                                                with: #""skillLevel":"pro""#)
        try #require(sample != ContractSamples.event)

        let event = try ContractSamples.decode(SportEvent.self, from: sample)
        #expect(event.skillLevel == Self.pro)
        #expect(event.id == "evt_01J" && event.type == .football)
        let json = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(event), encoding: .utf8))
        #expect(json.contains(#""skillLevel":"pro""#))
        #expect(try ContractSamples.decode(SportEvent.self, from: json) == event)
    }
}
