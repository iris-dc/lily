import Foundation
import Observation

/// Creates an invite for a group with the chosen expiry and use limit, and offers its link and code. Changing an
/// option after the invite exists drops and revokes it, so what is shared is always what the options say; an invite
/// that was neither shared nor copied is revoked when the sheet closes, since nobody can have received it.
@Observable
final class InviteViewModel {
    let group: SportGroup
    var expiresInDays = AppConfig.Groups.inviteDefaultDays {
        didSet { if oldValue != expiresInDays { discardInvite() } }
    }
    /// `0` is unlimited.
    var maxUses = AppConfig.Groups.inviteDefaultUses {
        didSet { if oldValue != maxUses { discardInvite() } }
    }
    private(set) var invite: Invite?
    /// For the UI only: a create for the current options is out. Which answer counts is decided by `generation`.
    private(set) var isCreating = false
    private(set) var codeCopied = false
    /// The share sheet was opened or the code copied. `ShareLink` does not say whether the link was actually sent,
    /// so an opened share sheet counts as shared and its invite is never revoked on close.
    private(set) var wasShared = false
    /// Bumped by every option change and by `close()`; the answer to an older create is revoked and dropped.
    private var generation = 0

    private let repository: any InviteRepository
    private let reporter: GroupErrorReporter
    private let recorder: any InteractionRecorder
    private let pasteboard: any Pasteboard
    private let logger: any Logging
    private let now: () -> Date

    init(group: SportGroup,
         repository: any InviteRepository,
         reporter: GroupErrorReporter,
         recorder: any InteractionRecorder,
         pasteboard: any Pasteboard,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.group = group
        self.repository = repository
        self.reporter = reporter
        self.recorder = recorder
        self.pasteboard = pasteboard
        self.logger = logger
        self.now = now
    }

    var options: InviteOptions { InviteOptions(maxUses: maxUses, expiresInDays: expiresInDays) }
    var shareText: String { AppBranding.Groups.Invite.shareText(groupName: group.name) }
    var shareURL: URL? { invite?.url }
    var formattedCode: String? { invite?.formattedCode }
    var canShare: Bool { invite != nil && !isCreating }

    /// Asks the backend for an invite with the current options; quiet when the sheet went away. An answer to a
    /// create the options moved past is revoked instead of shown. A create cancelled by the sheet (its `.task(id:)`
    /// restarts on an option change) may still have landed on the backend; that invite is not revoked and expires on
    /// its own.
    func create() async {
        guard invite == nil else { return }
        generation += 1
        let mine = generation
        isCreating = true
        defer { if mine == generation { isCreating = false } }
        do {
            let created = try await repository.create(groupID: group.id, options: options)
            guard mine == generation else {
                revoke(created)
                return
            }
            invite = created
            logger.info(.groups, "Invite \(created.inviteId) created for group \(group.id)")
        } catch {
            guard !AppError.isCancellation(error), mine == generation else { return }
            logger.error(.groups, "Invite creation failed for group \(group.id): \(error)")
            reporter.report(error)
        }
    }

    func copyCode() {
        guard let formattedCode else { return }
        pasteboard.copy(formattedCode)
        codeCopied = true
        recordShared()
    }

    /// The share sheet was opened or the code copied; only the group id is reported, never the code or the link.
    func recordShared() {
        wasShared = true
        recorder.record(.inviteShared(groupID: group.id, at: now()))
    }

    /// The sheet went away: an invite nobody could have received is revoked, the invite is dropped so a repeated call
    /// sends nothing, and a create still out is stale.
    func close() {
        generation += 1
        isCreating = false
        if let invite, !wasShared { revoke(invite) }
        invite = nil
    }

    /// The options changed: the invite made for the old ones is revoked, and a create still out is stale.
    private func discardInvite() {
        generation += 1
        isCreating = false
        if let invite { revoke(invite) }
        invite = nil
        codeCopied = false
        wasShared = false
    }

    /// Nothing waits on a revocation, and a failure is a warning, never a popup: the invite expires on its own.
    private func revoke(_ invite: Invite) {
        let groupID = group.id
        Task { [repository, logger] in
            do {
                _ = try await repository.revoke(groupID: groupID, inviteID: invite.inviteId)
                logger.info(.groups, "Invite \(invite.inviteId) revoked for group \(groupID)")
            } catch {
                logger.warning(.groups, "Invite \(invite.inviteId) revocation failed for group \(groupID): \(error)")
            }
        }
    }
}
