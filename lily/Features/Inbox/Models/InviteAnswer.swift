import Foundation

/// An invite's answer and its deadline, shared by the group and the tournament invite payloads so the cards judge
/// both the same way.
nonisolated protocol InviteAnswer {
    var status: InviteStatus { get }
    var expiresAt: Date { get }
}

nonisolated extension InviteAnswer {
    /// Pending and before its deadline: the one rule for offering Accept and Decline and for the mock's expiry refusal.
    func isOpen(now: Date) -> Bool {
        status == .pending && expiresAt > now
    }

    /// What an answered or lapsed invite says in place of its buttons; `nil` while it is still open.
    func statusCaption(now: Date) -> String? {
        if isOpen(now: now) { return nil }
        return switch status {
        case .accepted: AppBranding.Inbox.joined
        case .declined: AppBranding.Inbox.declined
        case .pending: AppBranding.Inbox.expired
        case .unknown: nil
        }
    }
}
