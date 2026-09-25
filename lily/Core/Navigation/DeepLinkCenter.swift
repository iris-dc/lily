import Foundation
import Observation

/// Where an invite link lands: the root view presents the preview for `pendingInvite` and clears it when the sheet
/// goes. Only `AppConfig.Groups.inviteLinkBaseURL/<code>` is recognised; anything else is ignored. The URL and the
/// code are secrets and never reach a log line.
@Observable
final class DeepLinkCenter {
    var pendingInvite: InviteCode?

    private let logger: any Logging

    /// `-open-invite <code>` (debug launches) seeds the preview the way a tapped link would.
    init(arguments: [String] = [], logger: any Logging) {
        self.logger = logger
        let flag = AppConfig.LaunchArguments.openInvite
        guard let raw = AppConfig.LaunchArguments.value(following: flag, in: arguments) else { return }
        if let code = InviteCode(raw) {
            pendingInvite = code
            logger.info(.groups, "Launch argument requested an invite preview")
        } else {
            logger.warning(.groups, "Ignoring \(flag): not a valid invite code")
        }
    }

    func handle(_ url: URL) {
        guard let code = Self.parse(url) else {
            logger.debug(.groups, "Ignored a URL that is not an invite link")
            return
        }
        pendingInvite = code
        logger.info(.groups, "Invite link received")
    }

    /// The code of an invite link: the base's scheme, host and path, then exactly one segment that is a valid code.
    nonisolated static func parse(_ url: URL) -> InviteCode? {
        let base = AppConfig.Groups.inviteLinkBaseURL
        guard url.scheme?.lowercased() == base.scheme, url.host()?.lowercased() == base.host() else { return nil }
        let basePath = base.pathComponents
        let path = url.pathComponents
        guard path.count == basePath.count + 1, Array(path.prefix(basePath.count)) == basePath else { return nil }
        return InviteCode(path[basePath.count])
    }
}
