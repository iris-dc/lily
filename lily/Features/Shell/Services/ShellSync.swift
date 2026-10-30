import Foundation

/// The shell's per-user work: the restore that lands on the start tab, and the sync that runs for every scene phase
/// and user. The order in `run` is load-bearing: the account loads before the connection, because
/// `RemoteRealtimeEndpointProvider` reads `me.realtimeEndpoint`; the connection comes before Mine, because a connection
/// that opens reloads Mine itself (the resume protocol), so the store's own load afterwards is usually a no-op; the
/// inbox follows Mine, the block list the inbox (every room's rows read it), and the push offer and registration come
/// last. A run stops at the first await after it was cancelled, so the phase it read is never applied over a newer one;
/// the check before `setDesired` matters most, since `resume()` sets `isActive` unconditionally and a stale run must
/// never reopen a connection the background run closed. Every run first joins the session's check against the pool,
/// so nothing loads for a user the pool has not confirmed (the loads need the token that check obtains anyway). The
/// start tab is picked from the cached session when the root is built; a check that changed the state moves it in the
/// same turn (`AppNavigation.sessionDidRestore`, `sessionDidEnd`), before the restore opens a pending notification tap,
/// or the tab would overwrite the screen the tap opened.
/// Explore's lists load alongside the chain for a guest or a signed-in user, so the tab holds a fresh answer before it
/// is first opened; a signed-out visitor is on the landing and is asked for nothing.
final class ShellSync {
    private let session: SessionController
    private let me: MeStore
    private let realtime: RealtimeSessionController
    private let myGroups: MyGroupsStore
    private let inbox: InboxStore
    private let blocks: BlockListStore
    private let push: PushCoordinator
    private let lists: ShellLists

    init(session: SessionController,
         me: MeStore,
         realtime: RealtimeSessionController,
         myGroups: MyGroupsStore,
         inbox: InboxStore,
         blocks: BlockListStore,
         push: PushCoordinator,
         lists: ShellLists) {
        self.session = session
        self.me = me
        self.realtime = realtime
        self.myGroups = myGroups
        self.inbox = inbox
        self.blocks = blocks
        self.push = push
        self.lists = lists
    }

    /// Verifies the cached session with the pool, then opens a notification tapped before the restore.
    func restore() async {
        await session.restore()
        await push.openPendingTap()
    }

    /// In the background only the connection is told to close. A guest needs no guard here: every store and coordinator
    /// guards on the identity itself and clears when the session ends. A return before the end (a cancelled run)
    /// cancels Explore's loads with it.
    func run(active: Bool, user: AuthUser?) async {
        await session.restore()
        guard !Task.isCancelled else { return }
        async let explore: Void = loadExploreIfStale(active: active)
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
        await explore
    }

    /// Not on the landing: a signed-out visitor may never pass it, a sign-in reloads by caller anyway, and the position
    /// the list asks for would put the permission alert over the intro. The state is read after the session check.
    private func loadExploreIfStale(active: Bool) async {
        guard active, session.state != .signedOut else { return }
        await lists.loadExploreIfStale()
    }
}
