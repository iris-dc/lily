import Foundation
import Testing
@testable import lily

@MainActor
struct MeStoreTests {
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

    @Test func loadsOncePerUserAndExposesTheAccount() async {
        repository.meResult = .success(.fixture(isOperator: true))
        let store = makeStore()

        await store.loadIfNeeded()
        await store.loadIfNeeded()
        #expect(repository.meCallCount == 1)
        #expect(store.isOperator && !store.needsTerms && store.realtimeEndpoint == nil)

        identity.currentUserID = "someone-else"
        await store.loadIfNeeded()
        #expect(repository.meCallCount == 2)
    }

    @Test func guestsHaveNoAccountAndCauseNoRequest() async {
        let store = makeStore()
        await store.loadIfNeeded()
        #expect(store.account != nil)

        identity.currentUserID = nil
        await store.loadIfNeeded()

        #expect(store.account == nil && repository.meCallCount == 1 && !store.needsTerms)
    }

    /// The load is bookkeeping: a failure is logged, never shown, and the next `loadIfNeeded` tries again.
    @Test func aFailedLoadIsLoggedNotShownAndRetried() async {
        repository.meResult = .failure(.network)
        let store = makeStore()

        await store.loadIfNeeded()
        #expect(store.account == nil && errorCenter.current == nil)
        #expect(logger.messages(in: .groups, at: .warning).count == 1)

        repository.meResult = .success(.fixture())
        await store.loadIfNeeded()
        #expect(store.account != nil && repository.meCallCount == 2)
    }

    @Test func outdatedTermsAreOwedUntilAccepted() async {
        repository.meResult = .success(.fixture(termsVersion: 2, acceptedTermsVersion: 1))
        let store = makeStore()
        await store.loadIfNeeded()
        #expect(store.needsTerms)

        #expect(await store.acceptTerms())

        #expect(repository.acceptedVersions == [2] && !store.needsTerms)
        #expect(logger.messages(in: .groups, at: .info).contains("Terms accepted (version 2)"))
    }

    @Test func aRefusedWriteRaisesTheTermsAgain() async {
        let store = makeStore()
        await store.loadIfNeeded()
        #expect(!store.needsTerms)

        store.noteTermsRequired()
        #expect(store.needsTerms)

        #expect(await store.acceptTerms())
        #expect(!store.needsTerms)
    }

    @Test func aFailedAcceptanceReachesThePopup() async {
        repository.acceptError = .network
        let store = makeStore()
        await store.loadIfNeeded()

        #expect(await store.acceptTerms() == false)
        #expect(errorCenter.current?.error == .network)
        #expect(await makeStore().acceptTerms() == false, "nothing to accept before the account is known")
    }

    @Test func signOutClearsTheAccount() async {
        let store = makeStore()
        await store.loadIfNeeded()
        store.noteTermsRequired()

        store.sessionDidEnd()

        #expect(store.account == nil && !store.needsTerms && !store.isOperator)
    }
}
