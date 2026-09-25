import Foundation
import Testing
@testable import lily

struct RealtimeEnvelopeTests {
    private let groupID = "7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d"

    @Test func messageEnvelopeCarriesTheFullMessage() throws {
        let envelope = try ContractSamples.decode(RealtimeEnvelope.self, from: ContractSamples.messageEnvelope)

        guard case .message(let message) = envelope else { Issue.record("expected .message"); return }
        #expect(message.id == "01J8ZK7Q9X2M4N6P8R0T2V4W6Y" && message.groupId == groupID)
        #expect(message.senderName == "Marta" && message.text == "Thursday works for me." && !message.isDeleted)
        #expect(message.clientMessageId == "3f2504e0-4f89-11d3-9a0c-0305e82c3302" && message.kind == .text)
        #expect(envelope.groupID == groupID && envelope.channelEpoch == nil)
    }

    @Test func messageDeletedNamesTheGroupAndTheMessage() throws {
        let envelope = try ContractSamples.decode(RealtimeEnvelope.self, from: ContractSamples.messageDeletedEnvelope)
        #expect(envelope == .messageDeleted(groupID: groupID, id: "01J8ZK7Q9X2M4N6P8R0T2V4W6Y"))
    }

    @Test func memberJoinedAndLeftCarryCountsAndEpochs() throws {
        let joined = try ContractSamples.decode(RealtimeEnvelope.self, from: ContractSamples.memberJoinedEnvelope)
        let left = try ContractSamples.decode(RealtimeEnvelope.self, from: ContractSamples.memberLeftEnvelope)

        guard case .memberJoined(let joinedGroup, let member, let count, let epoch) = joined else {
            Issue.record("expected .memberJoined")
            return
        }
        #expect(joinedGroup == groupID && member.displayName == "Marta" && count == 35 && epoch == 3)
        #expect(left == .memberLeft(groupID: groupID, userID: "seed-jonas", channelEpoch: 4, memberCount: 33))
        #expect(left.channelEpoch == 4 && joined.channelEpoch == 3)
    }

    @Test func groupEventsDecode() throws {
        let updated = try ContractSamples.decode(RealtimeEnvelope.self, from: ContractSamples.groupUpdatedEnvelope)
        let deleted = try ContractSamples.decode(RealtimeEnvelope.self, from: ContractSamples.groupDeletedEnvelope)
        let changed = try ContractSamples.decode(RealtimeEnvelope.self, from: ContractSamples.membershipChange)

        guard case .groupUpdated(let group) = updated else { Issue.record("expected .groupUpdated"); return }
        #expect(group.id == groupID && group.channelEpoch == 3 && updated.channelEpoch == 3)
        #expect(deleted == .groupDeleted(groupID: groupID))
        guard case .membershipChanged(let change) = changed else { Issue.record("expected .membershipChanged"); return }
        #expect(change.groupId == "g1" && change.change == .roleChanged && change.role == .admin && changed.channelEpoch == 4)
    }

    /// A newer backend may publish types this build does not know; the stream must survive them.
    @Test func unknownTypesAreTolerated() throws {
        let envelope = try ContractSamples.decode(RealtimeEnvelope.self, from: ContractSamples.unknownEnvelope)
        #expect(envelope == .unknown(type: "typing"))
        #expect(envelope.groupID == nil && envelope.channelEpoch == nil)
    }

    @Test func messageKindsDecodeByWireName() throws {
        let system = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.systemMessage)
        let deleted = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.deletedMessage)
        #expect(system.kind == .eventCreated && system.isSystem && system.eventId == "evt_01J" && system.text == nil)
        #expect(deleted.isDeleted && deleted.text == nil && deleted.clientMessageId == nil)
    }

    /// AppSync meters 5 KB units: a Latin message at the cap is one unit, a CJK one two, both far under the 240 KB limit.
    @Test func payloadSizesStayWithinTheMeteringUnits() throws {
        let latin = try envelopeSize(text: String(repeating: "a", count: AppConfig.Chat.messageMaxLength))
        let cjk = try envelopeSize(text: String(repeating: "語", count: AppConfig.Chat.messageMaxLength))

        #expect(latin < 5 * 1024, "Latin message envelope is \(latin) bytes")
        #expect(cjk < 8 * 1024, "CJK message envelope is \(cjk) bytes")
    }

    private func envelopeSize(text: String) throws -> Int {
        let message = ChatMessage.fixture(id: "01J8ZK7Q9X2M4N6P8R0T2V4W6Y",
                                          groupID: groupID,
                                          senderUserID: "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
                                          senderName: String(repeating: "N", count: 40),
                                          text: text,
                                          clientMessageID: "3f2504e0-4f89-11d3-9a0c-0305e82c3302")
        let body = try APIJSONCoding.makeEncoder().encode(message)
        let envelope = Data(#"{"type":"message","message":"#.utf8) + body + Data("}".utf8)
        _ = try APIJSONCoding.makeDecoder().decode(RealtimeEnvelope.self, from: envelope)
        return envelope.count
    }
}

struct RealtimeChannelTests {
    @Test func pathsFollowTheNamespaces() {
        #expect(RealtimeChannel.room(groupID: "g1", epoch: 3).path == "rooms/g1/3")
        #expect(RealtimeChannel.user(sub: "u-1").path == "users/u-1")
        #expect(RealtimeChannel.room(groupID: "g1", epoch: 3).groupID == "g1")
        #expect(RealtimeChannel.user(sub: "u-1").groupID == nil)
    }
}
