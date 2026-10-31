import Foundation
import Testing
@testable import lily

/// The file store, each test under a directory of its own: suites run concurrently, and a clear sweeps the directory.
@MainActor
struct ListSnapshotStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "list-snapshots-\(UUID().uuidString)")
    private let logger = SpyLogger()
    private let key = ListSnapshotKey(list: "events-upcoming", userID: TestFixtures.user.id)
    private let events = [SportEvent.fixture(id: "a", startsAt: Date(timeIntervalSince1970: 1_800_000_000)),
                          .fixture(id: "b", startsAt: Date(timeIntervalSince1970: 1_800_003_600), isJoined: true)]

    private func makeStore() -> FileListSnapshotStore {
        FileListSnapshotStore(directory: directory, logger: logger)
    }

    private func removeDirectory() {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func aSavedListComesBackAsItWentIn() {
        defer { removeDirectory() }
        let store = makeStore()

        store.save(events, for: key)

        #expect(store.load([SportEvent].self, for: key) == events)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: key.fileName).path()))
        #expect(logger.messages(in: .cache).filter { $0.contains("Snapshot hit for events-upcoming") }.count == 1)
    }

    @Test func nothingSavedIsAMiss() {
        defer { removeDirectory() }

        #expect(makeStore().load([SportEvent].self, for: key) == nil)
        #expect(logger.messages(in: .cache).filter { $0.contains("Snapshot miss for events-upcoming") }.count == 1)
    }

    /// A model that changed shape since the last run reads as a miss, and the file goes, so the next launch is a plain miss.
    @Test func anUnreadableSnapshotIsDiscarded() throws {
        defer { removeDirectory() }
        let store = makeStore()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: key.fileName)
        try Data("not json".utf8).write(to: file)

        #expect(store.load([SportEvent].self, for: key) == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path()))
        #expect(logger.messages(in: .cache, at: .warning).filter { $0.contains("unreadable") }.count == 1)
    }

    /// Mine and the joined flags are one caller's: a guest and a user never read each other's snapshot.
    @Test func snapshotsAreKeptPerCaller() {
        defer { removeDirectory() }
        let store = makeStore()
        let guest = ListSnapshotKey(list: key.list, userID: nil)
        store.save(events, for: key)
        store.save([events[0]], for: guest)

        #expect(store.load([SportEvent].self, for: key) == events)
        #expect(store.load([SportEvent].self, for: guest) == [events[0]])
        #expect(guest.fileName == "events-upcoming.guest.json" && key.fileName == "events-upcoming.u-1.json")
    }

    /// The session ending takes every snapshot with it, so the next account starts from nothing of the last one's.
    @Test func theSessionEndingClearsEverySnapshot() {
        defer { removeDirectory() }
        let store = makeStore()
        store.save(events, for: key)
        store.save([SportGroup.fixture(id: "g")], for: ListSnapshotKey(list: "groups-mine", userID: TestFixtures.user.id))

        store.sessionDidEnd()

        #expect(store.load([SportEvent].self, for: key) == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.path()))
        #expect(logger.messages(in: .cache).filter { $0.contains("List snapshots cleared") }.count == 1)
    }

    /// A build that reads the snapshots differently sweeps what an older one wrote (`AppConfig.Lists.snapshotFormat`),
    /// marker or none; the current format's are kept, and a save writes the marker again.
    @Test func snapshotsOfAnotherFormatAreSweptWhenTheStoreStarts() throws {
        defer { removeDirectory() }
        let marker = directory.appending(path: AppConfig.Lists.snapshotFormatFileName)
        makeStore().save(events, for: key)
        #expect(try String(contentsOf: marker, encoding: .utf8) == String(AppConfig.Lists.snapshotFormat))
        #expect(makeStore().load([SportEvent].self, for: key) == events, "the current format is kept")

        try "1".write(to: marker, atomically: true, encoding: .utf8)
        #expect(makeStore().load([SportEvent].self, for: key) == nil)
        #expect(logger.messages(in: .cache).filter { $0.contains("of format 1 swept") }.count == 1)

        makeStore().save(events, for: key)
        try FileManager.default.removeItem(at: marker)
        #expect(makeStore().load([SportEvent].self, for: key) == nil, "no marker is an older build's directory")
        #expect(logger.messages(in: .cache).filter { $0.contains("of format none swept") }.count == 1)
        #expect(!FileManager.default.fileExists(atPath: directory.path()))
    }

    @Test func clearingNothingIsNoError() {
        makeStore().clear()

        #expect(logger.messages(in: .cache, at: .warning).isEmpty)
    }
}
