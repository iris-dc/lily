import Foundation
import Testing
@testable import lily

/// When the terms sheet shows, what closes it, and that a tap while accepting is dropped.
@MainActor
struct TermsViewModelTests {
    private let repository = FakeMeRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter
    private let me: MeStore
    private let signOuts = CallCounter()

    init() {
        errorCenter = ErrorCenter(logger: logger)
        me = MeStore(repository: repository, identity: identity, errorCenter: errorCenter, logger: logger)
    }

    /// Signing out does what the app's session observers do: the identity forgets the caller and the store clears.
    private func makeViewModel() -> TermsViewModel {
        TermsViewModel(me: me, identity: identity, logger: logger) { [signOuts, identity, me] in
            signOuts.increment()
            identity.currentUserID = nil
            me.sessionDidEnd()
        }
    }

    @Test func aNewAccountIsAskedForTheTermsOnceTheAccountLoaded() async {
        repository.meResult = .success(.fixture(acceptedTermsVersion: nil))
        let viewModel = makeViewModel()
        #expect(!viewModel.isPresented)

        await me.loadIfNeeded()

        #expect(viewModel.isPresented)
    }

    @Test func anAccountWithTheTermsAcceptedIsNotAsked() async {
        let viewModel = makeViewModel()

        await me.loadIfNeeded()

        #expect(!viewModel.isPresented)
    }

    /// A write answered `TERMS_REQUIRED` after a clean load: the version moved since.
    @Test func aTermsRequiredRefusalRaisesTheSheet() async {
        let viewModel = makeViewModel()
        await me.loadIfNeeded()
        #expect(!viewModel.isPresented)

        me.noteTermsRequired()

        #expect(viewModel.isPresented)
    }

    /// `MeStore.termsOutdated` can be set without an account, and a guest has no account to load.
    @Test func aGuestIsNeverAsked() async {
        identity.currentUserID = nil
        let viewModel = makeViewModel()

        me.noteTermsRequired()
        #expect(!viewModel.isPresented)

        await me.loadIfNeeded()
        #expect(!viewModel.isPresented && repository.meCallCount == 0)
    }

    @Test func aSuccessfulAcceptClosesTheSheet() async {
        repository.meResult = .success(.fixture(acceptedTermsVersion: nil))
        let viewModel = makeViewModel()
        await me.loadIfNeeded()

        await viewModel.accept()

        #expect(!viewModel.isPresented && !viewModel.isAccepting)
        #expect(repository.acceptedVersions == [1])
    }

    @Test func aFailedAcceptKeepsTheSheetAndShowsThePopup() async {
        repository.meResult = .success(.fixture(acceptedTermsVersion: nil))
        let viewModel = makeViewModel()
        await me.loadIfNeeded()
        repository.acceptError = .network

        await viewModel.accept()

        #expect(viewModel.isPresented && !viewModel.isAccepting)
        #expect(errorCenter.current?.error == .network)
    }

    /// The hold keeps the accept's reload of the account in flight, so the second tap meets `isAccepting`.
    @Test func aSecondTapWhileAcceptingIsDropped() async {
        repository.meResult = .success(.fixture(acceptedTermsVersion: nil))
        let viewModel = makeViewModel()
        await me.loadIfNeeded()
        repository.holdsRequests = true

        let first = Task { await viewModel.accept() }
        await settle(until: { viewModel.isAccepting })
        await viewModel.accept()
        repository.releaseRequests()
        await first.value

        #expect(repository.acceptedVersions.count == 1 && !viewModel.isAccepting)
    }

    @Test func signingOutClosesTheSheet() async {
        repository.meResult = .success(.fixture(acceptedTermsVersion: nil))
        let viewModel = makeViewModel()
        await me.loadIfNeeded()
        #expect(viewModel.isPresented)

        await viewModel.signOut()

        #expect(signOuts.count == 1 && !viewModel.isPresented)
        #expect(logger.messages(in: .groups, at: .info).contains("Terms declined: signing out"))
    }
}
