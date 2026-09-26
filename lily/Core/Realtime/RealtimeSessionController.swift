import Foundation
import Observation

/// The one realtime connection of a signed-in, foregrounded app: `users/<sub>` plus the open room and the most
/// recently active groups of Mine. Opens when the app is active with a user and an endpoint, closes on background
/// and sign-out, renews itself with a fresh token before the token expires, and recovers over REST whatever the socket
/// missed (`RealtimeSessionController+Connection.swift`). Envelopes are applied to the shared room cache and handed to
/// whoever listens through `envelopes(for:)` (`RealtimeSessionController+Routing.swift`).
@Observable
final class RealtimeSessionController: SessionObserver {
    var state: RealtimeConnectionState = .disconnected
    /// The epoch each room is subscribed at.
    var subscribedRooms: [String: Int] = [:]
    var openRoom: RoomSubscription?

    /// Someone reading `envelopes(for:)` or `userEnvelopes()`; `groupID` is `nil` for the user channel.
    struct Consumer {
        let groupID: String?
        let continuation: AsyncStream<RealtimeEnvelope>.Continuation
    }

    var isActive = false
    var user: AuthUser?
    /// Mine, most recently active first; the subscription set is cut from it.
    var wantedRooms: [RoomSubscription] = []
    /// The newest epoch learned for a group from any source; an epoch only ever grows.
    var knownEpochs: [String: Int] = [:]
    var connectionGeneration = 0
    /// The connect in flight; it answers whether a `close()` superseded it while a connection was still wanted.
    var connectionTask: Task<Bool, Never>?
    var renewalTask: Task<Void, Never>?
    var reconnectTask: Task<Void, Never>?
    var subscriptions: [RealtimeChannel: Task<Void, Never>] = [:]
    var pendingResubscribes: [String: Task<Void, Never>] = [:]
    var consumers: [UUID: Consumer] = [:]
    var lastExpiry: Date?
    var backoffAttempt = 0
    var reportedExpiredSession = false

    let transport: any RealtimeTransport
    let endpointProvider: any RealtimeEndpointProvider
    /// `nil` under the mock auth: no token exists, and the mock transport needs none.
    let tokenProvider: (any AuthTokenProvider)?
    let identity: any IdentityProvider
    let store: MyGroupsStore
    let cache: any ChatHistoryCache
    let catchUp: ChatCatchUp
    let unread: UnreadCenter
    let groupChanges: ChangeTracker
    let groupRepository: any GroupRepository
    let errorCenter: ErrorCenter
    let logger: any Logging
    let now: () -> Date
    let sleep: Sleep
    /// A number in the range, for jitter; tests pin it.
    let random: (ClosedRange<Double>) -> Double

    init(transport: any RealtimeTransport,
         endpointProvider: any RealtimeEndpointProvider,
         tokenProvider: (any AuthTokenProvider)?,
         identity: any IdentityProvider,
         store: MyGroupsStore,
         cache: any ChatHistoryCache,
         catchUp: ChatCatchUp,
         unread: UnreadCenter,
         groupChanges: ChangeTracker,
         groupRepository: any GroupRepository,
         errorCenter: ErrorCenter,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         sleep: @escaping Sleep = systemSleep,
         random: @escaping (ClosedRange<Double>) -> Double = { Double.random(in: $0) }) {
        self.transport = transport
        self.endpointProvider = endpointProvider
        self.tokenProvider = tokenProvider
        self.identity = identity
        self.store = store
        self.cache = cache
        self.catchUp = catchUp
        self.unread = unread
        self.groupChanges = groupChanges
        self.groupRepository = groupRepository
        self.errorCenter = errorCenter
        self.logger = logger
        self.now = now
        self.sleep = sleep
        self.random = random
    }

    /// The single input from the shell: whether the scene is in the foreground and who is signed in.
    func setDesired(active: Bool, user: AuthUser?) async {
        if user?.id != self.user?.id {
            await close(reason: "session changed")
            resetSessionState()
        }
        self.user = user
        if active {
            await resume()
        } else {
            await suspend()
        }
    }

    /// `.background`: the connection is closed; nothing is delivered to a suspended app anyway. The close is its own
    /// task, so the shell's sync being cancelled by the next phase change cannot leave the transport half-closed.
    func suspend() async {
        isActive = false
        await Task { await close(reason: "background") }.value
    }

    /// `.active`, and whenever the connection is re-established: connect, subscribe, then recover over REST. When no
    /// connection comes up (no endpoint, no token, the open failed), the open room alone is caught up over REST on a
    /// return from the background, so it still shows what arrived while the app was away. An `.active` <-> `.inactive`
    /// flip re-runs this without a suspend and fetches nothing, because nothing was missed.
    func resume() async {
        let wasSuspended = !isActive
        isActive = true
        await connect(fresh: false)
        if wasSuspended { await catchUpOpenRoomWithoutConnection() }
    }

    /// Takes the room set from Mine; called after every change of the store.
    func syncRooms() {
        setRooms(store.groups.map(RoomSubscription.init))
    }

    func setRooms(_ rooms: [RoomSubscription]) {
        wantedRooms = rooms
        rooms.forEach { noteEpoch($0.epoch, for: $0.groupID) }
        reconcileSubscriptions()
    }

    /// The chat on screen, always subscribed whatever its place in Mine.
    func setOpenRoom(_ room: RoomSubscription?) {
        openRoom = room
        if let room { noteEpoch(room.epoch, for: room.groupID) }
        reconcileSubscriptions()
    }

    /// Makes sure the room is subscribed at `room.epoch` (or a newer one already known), waiting out a jittered
    /// resubscribe if one is pending, so a caller can catch up afterwards knowing nothing falls in between.
    func ensureSubscribed(_ room: RoomSubscription) async {
        noteEpoch(room.epoch, for: room.groupID)
        if let pending = pendingResubscribes[room.groupID] {
            await pending.value
        }
        reconcileSubscriptions()
    }

    func subscribedEpoch(for groupID: String) -> Int? {
        subscribedRooms[groupID]
    }

    /// Everything that arrives for one room; ends when the caller stops reading.
    func envelopes(for groupID: String) -> AsyncStream<RealtimeEnvelope> {
        makeConsumerStream(groupID: groupID)
    }

    /// Everything that arrives on `users/<sub>`.
    func userEnvelopes() -> AsyncStream<RealtimeEnvelope> {
        makeConsumerStream(groupID: nil)
    }

    func sessionDidEnd() {
        user = nil
        wantedRooms = []
        openRoom = nil
        resetSessionState()
        Task { await close(reason: "sign-out") }
    }

    /// The desired set: the open room, then Mine up to `maxRoomSubscriptions`, each at the newest epoch known.
    func desiredRooms() -> [String: Int] {
        var desired: [String: Int] = [:]
        if let openRoom {
            desired[openRoom.groupID] = knownEpochs[openRoom.groupID] ?? openRoom.epoch
        }
        for room in wantedRooms.prefix(AppConfig.Realtime.maxRoomSubscriptions) where desired[room.groupID] == nil {
            desired[room.groupID] = knownEpochs[room.groupID] ?? room.epoch
        }
        return desired
    }

    func noteEpoch(_ epoch: Int, for groupID: String) {
        knownEpochs[groupID] = max(epoch, knownEpochs[groupID] ?? 0)
    }

    private func resetSessionState() {
        knownEpochs = [:]
        lastExpiry = nil
        backoffAttempt = 0
        reportedExpiredSession = false
    }

    private func makeConsumerStream(groupID: String?) -> AsyncStream<RealtimeEnvelope> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<RealtimeEnvelope>.makeStream()
        consumers[id] = Consumer(groupID: groupID, continuation: continuation)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.consumers[id] = nil }
        }
        return stream
    }
}
