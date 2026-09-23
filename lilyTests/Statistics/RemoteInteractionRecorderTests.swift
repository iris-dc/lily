import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteInteractionRecorderTests {
    private let client = FakeAPIClient()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let sleep = HeldSleep()
    private let flushDelay: Duration = .seconds(30)

    /// `nonisolated`: read by the stored property initialisers below.
    nonisolated private static let date = Date(timeIntervalSince1970: 1_800_000_000)
    private let viewed = Interaction.viewed(.fixture(id: "evt", hostUserId: "host"), at: Self.date)
    private let switched = Interaction.presentationChanged(.map, at: Self.date)

    private func makeRecorder(batchSize: Int = 3, maxBuffered: Int = 5) -> RemoteInteractionRecorder {
        RemoteInteractionRecorder(client: client,
                                  identity: identity,
                                  logger: logger,
                                  batchSize: batchSize,
                                  flushDelay: flushDelay,
                                  maxBuffered: maxBuffered) { [sleep] in try await sleep.sleep(for: $0) }
    }

    private var sentBatches: [InteractionBatch] { client.requests.compactMap { $0.body as? InteractionBatch } }

    /// Gives fire-and-forget work every chance to run, so "nothing more happened" can be asserted.
    private func yield() async {
        for _ in 0..<20 { await Task.yield() }
    }

    @Test func guestsAreNeverRecorded() async {
        identity.currentUserID = nil
        let recorder = makeRecorder()

        recorder.record(viewed)
        await recorder.flush()

        #expect(client.requests.isEmpty)
        #expect(sleep.requested.isEmpty, "no timer is armed for nothing")
        #expect(logger.messages(in: .statistics, at: .debug).contains { $0.contains("Guest event_viewed") })
    }

    @Test func flushPostsOneBatchToTheInteractionsPath() async throws {
        client.responses = [InteractionReceipt(accepted: 2)]
        let recorder = makeRecorder()

        recorder.record(viewed)
        recorder.record(switched)
        await recorder.flush()

        let request = try #require(client.requests.first)
        #expect(request.method == .post)
        #expect(request.path == "/api/interactions")
        #expect(request.queryItems.isEmpty)
        #expect(sentBatches == [InteractionBatch(interactions: [viewed, switched])])
        #expect(logger.messages(in: .statistics, at: .info).contains { $0.contains("Sent 2") && $0.contains("accepted 2") })
    }

    @Test func reachingTheBatchSizeSendsWithoutWaiting() async {
        client.responses = [InteractionReceipt(accepted: 3)]
        let recorder = makeRecorder(batchSize: 3)

        for _ in 0..<3 { recorder.record(viewed) }
        await settle(until: { client.requests.count == 1 })

        #expect(sentBatches.first?.interactions.count == 3)
        await yield()
        #expect(client.requests.count == 1, "the timer armed by the first record must not send again")
    }

    @Test func aSmallBatchIsSentAfterTheDelayByOneTimer() async {
        client.responses = [InteractionReceipt(accepted: 2)]
        let recorder = makeRecorder()

        recorder.record(viewed)
        recorder.record(switched)
        await settle(until: { sleep.requested.count == 1 })
        #expect(sleep.requested == [flushDelay])
        #expect(client.requests.isEmpty)

        sleep.release()
        await settle(until: { client.requests.count == 1 })
        #expect(sentBatches == [InteractionBatch(interactions: [viewed, switched])])
    }

    @Test func anExplicitFlushCancelsThePendingTimer() async {
        client.responses = [InteractionReceipt(accepted: 1)]
        let recorder = makeRecorder()
        recorder.record(viewed)
        await settle(until: { sleep.requested.count == 1 })

        await recorder.flush()
        await yield()

        #expect(client.requests.count == 1)
        #expect(sentBatches.first?.interactions == [viewed])
    }

    @Test func entriesOfAnotherUserAreDropped() async {
        client.responses = [InteractionReceipt(accepted: 1)]
        let recorder = makeRecorder()
        recorder.record(viewed)

        identity.currentUserID = "someone-else"
        recorder.record(switched)
        await recorder.flush()

        #expect(sentBatches == [InteractionBatch(interactions: [switched])])
        #expect(logger.messages(in: .statistics, at: .debug).contains { $0.contains("Dropped 1") })
    }

    @Test func signingOutBeforeTheFlushDropsEverything() async {
        let recorder = makeRecorder()
        recorder.record(viewed)

        identity.currentUserID = nil
        await recorder.flush()

        #expect(client.requests.isEmpty)
    }

    /// Statistics are never worth a popup or a retry: the batch is lost, and the log says so.
    @Test func aFailedSendIsLoggedNeverThrownAndNotRetried() async {
        client.error = APIError.http(status: 500, body: nil)
        let recorder = makeRecorder()
        recorder.record(viewed)

        await recorder.flush()
        client.error = nil
        await recorder.flush()

        #expect(client.requests.count == 1)
        #expect(logger.messages(in: .statistics, at: .warning).contains { $0.contains("Sending 1 interactions failed") })
    }

    @Test func theBufferKeepsOnlyTheNewestBeyondItsCap() async {
        client.responses = [InteractionReceipt(accepted: 2)]
        let recorder = makeRecorder(batchSize: 100, maxBuffered: 2)
        let dates = (0..<3).map { Date(timeIntervalSince1970: TimeInterval($0)) }

        for date in dates { recorder.record(.presentationChanged(.list, at: date)) }
        await recorder.flush()

        #expect(sentBatches.first?.interactions.map(\.occurredAt) == Array(dates[1...]))
        #expect(logger.messages(in: .statistics, at: .debug).contains { $0.contains("Buffer full") })
    }

    /// The timer task holds the recorder weakly: a recorder let go mid-delay is freed, not kept for the sleep.
    @Test func aSleepingTimerDoesNotKeepTheRecorderAlive() async {
        weak var released: RemoteInteractionRecorder?
        do {
            let recorder = makeRecorder()
            released = recorder
            recorder.record(viewed)
            await settle(until: { sleep.requested.count == 1 })
        }

        #expect(released == nil)
        sleep.release()
        await yield()
        #expect(client.requests.isEmpty, "the freed recorder sends nothing when its timer wakes")
    }

    @Test func anEmptyFlushSendsNothing() async {
        await makeRecorder().flush()

        #expect(client.requests.isEmpty)
    }
}
