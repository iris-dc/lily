import Foundation
import Testing
@testable import lily

/// The terms gate of `MeStore`: owed until accepted, re-raised by a refused write, and an acceptance that re-reads the
/// account so the version it sends is the current one.
@MainActor
struct MeStoreTermsTests {
    private let repository = FakeMeRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter

    init() {
        errorCenter = ErrorCenter(logger: logger)
    }

    private func makeStore() -> MeStore {
        MeStore(repository: repository, identity: identity, errorCenter: errorCenter, logger: logger)
    }

    /// Laurel omits `acceptedTermsVersion` for a newcomer.
    @Test func aNewAccountOwesTheTermsUntilAccepted() async {
        repository.meResult = .success(.fixture(acceptedTermsVersion: nil))
        let store = makeStore()
        await store.loadIfNeeded()
        #expect(store.needsTerms)

        #expect(await store.acceptTerms())

        #expect(repository.acceptedVersions == [1] && !store.needsTerms)
        #expect(store.account?.acceptedTermsVersion == 1)
        #expect(logger.messages(in: .groups, at: .info).contains("Terms v1 accepted"))
    }

    /// The version sent is the one `GET /api/me` names now, not the one the screen was opened on.
    @Test func acceptingReloadsTheAccountAndSendsTheCurrentVersion() async {
        repository.meResult = .success(.fixture(termsVersion: 2, acceptedTermsVersion: 1))
        let store = makeStore()
        await store.loadIfNeeded()
        repository.meResult = .success(.fixture(termsVersion: 3, acceptedTermsVersion: 1))

        #expect(await store.acceptTerms())

        #expect(repository.meCallCount == 2 && repository.acceptedVersions == [3])
        #expect(store.account?.termsVersion == 3 && !store.needsTerms)
    }

    /// A write refused for a version bumped since the load: the acceptance covers the new version, not the old one.
    @Test func aRefusalForANewerVersionAcceptsTheNewVersion() async {
        repository.meResult = .success(.fixture(termsVersion: 1, acceptedTermsVersion: 1))
        let store = makeStore()
        await store.loadIfNeeded()
        #expect(!store.needsTerms)
        repository.meResult = .success(.fixture(termsVersion: 2, acceptedTermsVersion: 1))

        store.noteTermsRequired()
        #expect(store.needsTerms)

        #expect(await store.acceptTerms())
        #expect(repository.acceptedVersions == [2] && !store.needsTerms)
    }

    @Test func aLoadThatShowsTheTermsAcceptedEndsTheRefusal() async {
        let store = makeStore()
        await store.loadIfNeeded()
        store.noteTermsRequired()

        await store.reload()

        #expect(!store.needsTerms)
    }

    @Test func aLoadThatStillOwesTheTermsKeepsTheRefusal() async {
        let store = makeStore()
        await store.loadIfNeeded()
        store.noteTermsRequired()
        repository.meResult = .success(.fixture(termsVersion: 2, acceptedTermsVersion: 1))

        await store.reload()

        #expect(store.needsTerms)
    }

    @Test func aFailedAcceptKeepsTheTermsOwedAndShowsThePopup() async {
        repository.meResult = .success(.fixture(acceptedTermsVersion: nil))
        repository.acceptError = .network
        let store = makeStore()
        await store.loadIfNeeded()

        #expect(await store.acceptTerms() == false)

        #expect(store.needsTerms && errorCenter.current?.error == .network)
        #expect(logger.messages(in: .groups, at: .error).count == 1)
    }

    /// Nothing is sent for a version nobody read: the failed read is what the popup shows.
    @Test func anAcceptWhoseReloadFailsShowsThePopupAndSendsNothing() async {
        repository.meResult = .failure(.network)
        let store = makeStore()

        #expect(await store.acceptTerms() == false)

        #expect(repository.acceptedVersions.isEmpty && errorCenter.current?.error == .network)
    }

    /// No account and no failure after the reload is a sign-out meanwhile: nothing to send, nothing to show.
    @Test func anAcceptAfterSignOutIsQuiet() async {
        identity.currentUserID = nil
        let store = makeStore()

        #expect(await store.acceptTerms() == false)

        #expect(repository.acceptedVersions.isEmpty && repository.meCallCount == 0 && errorCenter.current == nil)
    }
}
