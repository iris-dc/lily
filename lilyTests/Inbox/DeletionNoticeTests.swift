import Foundation
import SwiftUI
import Testing
import UIKit
@testable import lily

/// The two account-deletion notices (the account-deletion contract, section 8), decoded with the app's conventions,
/// and the helpers the cards read.
struct DeletionNoticeTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func theCancellationNoticeDecodesEveryContractField() throws {
        let item = try ContractSamples.decode(InboxItem.self, from: ContractSamples.inboxEventCancelled)

        #expect(item.id == ContractSamples.inboxEventCancelledID && item.kind == .eventCancelled && item.isVisible)
        #expect(item.invite == nil && item.reminder == nil && item.inviteAnswer == nil)
        let payload = try #require(item.eventCancelled)
        #expect(payload.eventId == "evt_01J" && payload.title == "Sunset 5-a-side")
        #expect(payload.startsAt == APIJSONCoding.parseInstant("2026-11-09T18:30:00Z"))
        #expect(InboxItemKind(wireName: "event_cancelled") == .eventCancelled)
        #expect(InboxItemKind.eventCancelled.wireName == "event_cancelled")
    }

    @Test func theOwnershipNoticeDecodesEveryContractField() throws {
        let item = try ContractSamples.decode(InboxItem.self, from: ContractSamples.inboxOwnershipTransferred)

        #expect(item.id == ContractSamples.inboxOwnershipID && item.kind == .groupOwnershipTransferred && item.isVisible)
        let payload = try #require(item.groupOwnershipTransferred)
        #expect(payload.groupId == "7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d" && payload.groupName == "Sunday Padel Crew")
        #expect(InboxItemKind(wireName: "group_ownership_transferred") == .groupOwnershipTransferred)
        #expect(InboxItemKind.groupOwnershipTransferred.wireName == "group_ownership_transferred")
    }

    /// Neither notice is answerable; each captions the Chats row with its sentence, and one without its payload hides.
    @Test func theNoticesCaptionAndAnswerNothing() {
        #expect(InboxItem.eventCancelled().caption == "Sunset 5-a-side was cancelled")
        #expect(InboxItem.groupOwnershipTransferred().caption == "Sunday Padel Crew is now yours")
        #expect(InboxItem.eventCancelled().inviteAnswer == nil && InboxItem.groupOwnershipTransferred().inviteAnswer == nil)
        #expect(InboxItem.eventCancelled().responding(.accepted, at: Self.now) == InboxItem.eventCancelled(),
                "a notice has no answer")
        #expect(!InboxItem(id: "bare", kind: .eventCancelled, createdAt: Self.now).isVisible)
        #expect(!InboxItem(id: "bare", kind: .groupOwnershipTransferred, createdAt: Self.now).isVisible)
    }

    @Test func theCancellationTimeIsTheSharedTimeCaption() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 11))!
        let startsAt = now.addingTimeInterval(2 * .day)
        let payload = try #require(InboxItem.eventCancelled(startsAt: startsAt).eventCancelled)

        #expect(payload.startsAtCaption(now: now, calendar: calendar)
                == InboxTimeCaption.text(for: startsAt, now: now, calendar: calendar))
    }

    @Test func theCancellationMarkExists() {
        #expect(UIImage(systemName: DesignTokens.Symbols.eventCancelled) != nil)
    }
}

/// The ownership card's tap: the group the caller now owns, opened on Home from Mine.
@MainActor
struct DeletionNoticeOpeningTests {
    private let harness = GroupHarness()
    private let notice = InboxItem.groupOwnershipTransferred(id: "n1", groupID: "g9")

    @Test func openGroupOpensAGroupMineAlreadyHolds() async {
        harness.store.add(.fixture(id: "g9", name: "Sunday Padel Crew"))
        let viewModel = await harness.openInbox([notice])

        await viewModel.openGroup(for: notice)

        #expect(harness.navigation.selectedTab == .home && harness.navigation.homePath.count == 1)
        #expect(harness.repository.requestedScopes.isEmpty, "a group Mine holds is not refetched")
        #expect(!harness.inboxLogs(.info).mentioning("n1", "opened group g9").isEmpty)
    }

    @Test func openGroupReloadsMineWhenTheGroupIsNotHeldYet() async {
        harness.repository.result = .success([.fixture(id: "g9")])
        let viewModel = await harness.openInbox([notice])

        await viewModel.openGroup(for: notice)

        #expect(harness.repository.requestedScopes == [.mine], "Mine reloaded once for the notice")
        #expect(harness.navigation.selectedTab == .home && harness.navigation.homePath.count == 1)
    }

    @Test func aGroupMineNeverLearnsReachesThePopup() async {
        harness.repository.result = .success([])
        let viewModel = await harness.openInbox([notice])

        await viewModel.openGroup(for: notice)

        #expect(harness.presentedError == .groupNotFound && harness.navigation.homePath.isEmpty)
        #expect(harness.inboxLogs(.warning).mentioning("n1", "g9").count == 1)
    }

    /// `openGroup` is the ownership card's alone: an item of any other kind opens nothing.
    @Test func aCancellationOpensNothing() async {
        let cancelled = InboxItem.eventCancelled(id: "n2")
        let viewModel = await harness.openInbox([cancelled])

        await viewModel.openGroup(for: cancelled)

        #expect(harness.navigation.homePath.isEmpty && harness.repository.requestedScopes.isEmpty)
    }
}
