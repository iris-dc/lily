import Foundation
import Testing
@testable import lily

@MainActor
struct DeepLinkCenterTests {
    private let logger = SpyLogger()
    private let code = AppConfig.Groups.mockInviteCode
    private var inviteURL: URL { AppConfig.Groups.inviteLinkBaseURL.appending(path: code) }

    @Test func parsesAnInviteLinkIntoItsCode() {
        #expect(DeepLinkCenter.parse(inviteURL)?.value == code)
    }

    /// The backend normalises the same way, so a link retyped in lower case or with look-alikes still opens.
    @Test func parseNormalisesTheCode() {
        let url = AppConfig.Groups.inviteLinkBaseURL.appending(path: "krzb7k3mqx9p")
        #expect(DeepLinkCenter.parse(url)?.value == code)
    }

    @Test(arguments: [
        "http://api.iskra.red/invite/KRZB7K3MQX9P",
        "https://example.com/invite/KRZB7K3MQX9P",
        "https://api.iskra.red/invites/KRZB7K3MQX9P",
        "https://api.iskra.red/invite",
        "https://api.iskra.red/invite/KRZB7K3MQX9P/extra",
        "https://api.iskra.red/invite/KRZB7K3MQX9",
        "https://api.iskra.red/invite/KRZB7K3MQX9U",
        "https://api.iskra.red/events/abc",
    ])
    func rejectsEverythingButAnInviteLink(raw: String) {
        #expect(DeepLinkCenter.parse(URL(string: raw)!) == nil)
    }

    @Test func handlingAnInviteLinkSetsThePendingInvite() {
        let center = DeepLinkCenter(logger: logger)

        center.handle(inviteURL)

        #expect(center.pendingInvite?.value == code)
        #expect(logger.messages(in: .groups, at: .info) == ["Invite link received"])
    }

    @Test func handlingAnotherURLChangesNothing() {
        let center = DeepLinkCenter(logger: logger)

        center.handle(URL(string: "https://api.iskra.red/events/abc")!)

        #expect(center.pendingInvite == nil)
        #expect(logger.messages(in: .groups, at: .info).isEmpty)
    }

    @Test func openInviteArgumentSeedsThePendingInvite() {
        let center = DeepLinkCenter(arguments: [AppConfig.LaunchArguments.openInvite, code], logger: logger)

        #expect(center.pendingInvite?.value == code)
    }

    @Test func openInviteArgumentWithoutAValidCodeIsIgnoredWithAWarning() {
        let missing = DeepLinkCenter(arguments: [AppConfig.LaunchArguments.openInvite], logger: logger)
        let invalid = DeepLinkCenter(arguments: [AppConfig.LaunchArguments.openInvite, "nope"], logger: logger)

        #expect(missing.pendingInvite == nil && invalid.pendingInvite == nil)
        #expect(logger.messages(in: .groups, at: .warning).count == 1)
    }

    /// The code is the secret behind an invite: no log line may carry it, or the URL that does.
    @Test func neverLogsTheCode() {
        let center = DeepLinkCenter(arguments: [AppConfig.LaunchArguments.openInvite, code], logger: logger)
        center.handle(inviteURL)
        center.handle(URL(string: "https://example.com/invite/\(code)")!)

        #expect(!logger.entries.isEmpty)
        #expect(logger.entries.allSatisfy { !$0.message.contains(code) && !$0.message.contains("iskra") })
    }
}
