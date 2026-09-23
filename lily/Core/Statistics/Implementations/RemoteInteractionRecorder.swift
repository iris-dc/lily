import Foundation

/// Buffers interactions and posts them to Laurel: at `batchSize`, or `flushDelay` after the first one, or on `flush()`.
/// Guests are never recorded. Every entry remembers who it was recorded for, so a sign-out between recording and
/// sending drops it instead of charging it to the next user.
final class RemoteInteractionRecorder: InteractionRecorder {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    private struct Entry {
        let userID: String
        let interaction: Interaction
    }

    private let client: any APIClient
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let batchSize: Int
    private let flushDelay: Duration
    private let maxBuffered: Int
    private let sleep: Sleep
    private var buffer: [Entry] = []
    private var timer: Task<Void, Never>?

    init(client: any APIClient,
         identity: any IdentityProvider,
         logger: any Logging,
         batchSize: Int = AppConfig.Statistics.batchSize,
         flushDelay: Duration = AppConfig.Statistics.flushDelay,
         maxBuffered: Int = AppConfig.Statistics.maxBuffered,
         sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
        self.client = client
        self.identity = identity
        self.logger = logger
        self.batchSize = batchSize
        self.flushDelay = flushDelay
        self.maxBuffered = maxBuffered
        self.sleep = sleep
    }

    func record(_ interaction: Interaction) {
        guard let userID = identity.currentUserID else {
            logger.debug(.statistics, "Guest \(interaction.kind.rawValue) not recorded")
            return
        }
        buffer.append(Entry(userID: userID, interaction: interaction))
        dropOldestBeyondCapacity()
        logger.debug(.statistics, "Recorded \(interaction.kind.rawValue); buffered: \(buffer.count)")
        if buffer.count >= batchSize {
            Task { await flush() }
        } else if timer == nil {
            armTimer()
        }
    }

    func flush() async {
        timer?.cancel()
        timer = nil
        let entries = buffer
        buffer.removeAll()
        let interactions = entries.filter { $0.userID == identity.currentUserID }.map(\.interaction)
        if interactions.count < entries.count {
            logger.debug(.statistics, "Dropped \(entries.count - interactions.count) interactions of another user")
        }
        guard !interactions.isEmpty else { return }
        await send(interactions)
    }

    private func send(_ interactions: [Interaction]) async {
        let request = APIRequest<InteractionReceipt>.post(AppConfig.API.Paths.interactions,
                                                          body: InteractionBatch(interactions: interactions))
        do {
            let receipt = try await client.send(request, failingWith: .unknown)
            logger.info(.statistics, "Sent \(interactions.count) interactions; accepted \(receipt.accepted)")
        } catch {
            logger.warning(.statistics, "Sending \(interactions.count) interactions failed: \(error)")
        }
    }

    private func dropOldestBeyondCapacity() {
        let excess = buffer.count - maxBuffered
        guard excess > 0 else { return }
        buffer.removeFirst(excess)
        logger.debug(.statistics, "Buffer full; dropped the oldest \(excess)")
    }

    /// One timer at a time; a flush before it fires cancels it. `weak self`: the task must not keep a recorder alive
    /// for the length of the delay once its owner has let go of it.
    private func armTimer() {
        timer = Task { [weak self, sleep, flushDelay] in
            guard (try? await sleep(flushDelay)) != nil, let self else { return }
            await flush()
        }
    }
}
