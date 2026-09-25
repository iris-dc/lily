import Foundation
import Observation

/// Creates an invite for a group with the chosen expiry and use limit, and offers its link and code. Changing an
/// option after the invite exists drops it, so what is shared is always what the options say.
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
    private(set) var isCreating = false
    private(set) var codeCopied = false

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

    /// Asks the backend for an invite with the current options; one at a time, quiet when the sheet went away.
    func create() async {
        guard !isCreating, invite == nil else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            let created = try await repository.create(groupID: group.id, options: options)
            invite = created
            logger.info(.groups, "Invite \(created.inviteId) created for group \(group.id)")
        } catch {
            guard !AppError.isCancellation(error) else { return }
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

    /// The share sheet was opened; only the group id is reported, never the code or the link.
    func recordShared() {
        recorder.record(.inviteShared(groupID: group.id, at: now()))
    }

    private func discardInvite() {
        invite = nil
        codeCopied = false
    }
}
