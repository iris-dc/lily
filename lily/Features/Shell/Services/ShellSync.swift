import Foundation

/// The shell's per-user work: the restore that lands on the start tab, and the sync that runs for every scene phase
/// and user. The order in `run` is load-bearing: the account loads before the connection, because
/// `RemoteRealtimeEndpointProvider` reads `me.realtimeEndpoint`; the connection comes before Mine, because a connection
/// that opens reloads Mine itself (the resume protocol), so the store's own load afterwards is usually a no-op; the
/// inbox follows Mine, the block list the inbox (every room's rows read it), and the push offer and registration come
/// last. A run stops at the first await after it was cancelled, so the phase it read is never applied over a newer one;
/// the check before `setDesired` matters most, since `resume()` sets `isActive` unconditionally and a stale run must
/// never reopen a connection the background run closed. The restore picks the start tab before it opens a pending
/// notification tap, or the tab would overwrite the screen the tap opened.
final class ShellSync {
    private let session: SessionController
    private let navigation: AppNavigation
    private let me: MeStore
    private let realtime: RealtimeSessionController
    private let myGroups: MyGroupsStore
    private let inbox: InboxStore
    private let blocks: BlockListStore
    private let push: PushCoordinator

    init(session: SessionController,
         navigation: AppNavigation,
         me: MeStore,
         realtime: RealtimeSessionController,
         myGroups: MyGroupsStore,
         inbox: InboxStore,
         blocks: BlockListStore,
         push: PushCoordinator) {
        self.session = session
        self.navigation = navigation
        self.me = me
        self.realtime = realtime
        self.myGroups = myGroups
        self.inbox = inbox
        self.blocks = blocks
        self.push = push
    }

    /// Restores the session, lands on the start tab for it, then opens a notification tapped before the restore.
    func restore() async {
        await session.restore()
        navigation.selectedTab = AppNavigation.startTab(for: session.state)
        await push.openPendingTap()
    }

    /// In the background only the connection is told to close. A guest needs no guard here: every store and coordinator
    /// guards on the identity itself and clears when the session ends.
    func run(active: Bool, user: AuthUser?) async {
        if active { await me.loadIfNeeded() }
        guard !Task.isCancelled else { return }
        await realtime.setDesired(active: active, user: user)
        guard !Task.isCancelled else { return }
        if active { await myGroups.loadIfStale() }
        guard !Task.isCancelled else { return }
        if active { await inbox.loadIfStale() }
        guard !Task.isCancelled else { return }
        if active { await blocks.loadIfNeeded() }
        guard !Task.isCancelled, active else { return }
        // A signed-in user entering the app is asked for the permission once; a grant registers the device at once.
        await push.offerReminders()
        await push.sync()
    }
}
