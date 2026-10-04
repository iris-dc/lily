import Foundation

/// An invite's answer and its deadline, shared by the group and the tournament invite payloads so the cards judge
/// both the same way.
nonisolated protocol InviteAnswer {
    var status: InviteStatus { get }
    var expiresAt: Date { get }
}

nonisolated extension InviteAnswer {
    /// Accept and Decline are offered while the invite is pending and its time has not run out.
    func isOpen(now: Date) -> Bool {
        status == .pending && expiresAt > now
    }

    /// What an answered or lapsed invite says in place of its buttons; `nil` while it is still open.
    func statusCaption(now: Date) -> String? {
        switch status {
        case .accepted: AppBranding.Inbox.joined
        case .declined: AppBranding.Inbox.declined
        case .pending: expiresAt > now ? nil : AppBranding.Inbox.expired
        }
    }
}
