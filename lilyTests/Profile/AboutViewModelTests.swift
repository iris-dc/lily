import Foundation
import Testing
@testable import lily

/// The "About you" editor's model over the shared `ProfileFieldViewModel`: Save for a changed valid text, an emptied
/// field clearing the bio, the store's bio replaced by the answer, a refusal shown and the draft kept.
@MainActor
struct AboutViewModelTests {
    private let repository = FakeProfileRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter
    private let store: ProfileStore

    init() {
        errorCenter = ErrorCenter(logger: logger)
        store = ProfileStore(repository: repository, identity: identity, snapshots: InMemoryListSnapshotStore(), logger: logger)
    }

    private func makeViewModel() -> AboutViewModel {
        AboutViewModel(store: store, errorCenter: errorCenter, logger: logger)
    }

    @Test func saveIsOffUntilTheTextChangesAndIsValid() async {
        repository.profileResult = .success(.fixture(bio: "Padel on Sundays."))
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        #expect(viewModel.draft.text == "Padel on Sundays.", "the field starts from the store's bio")
        #expect(!viewModel.canSubmit, "nothing to save until something changed")

        viewModel.draft.text = String(repeating: "x", count: AppConfig.About.maxLength + 1)
        #expect(!viewModel.canSubmit && viewModel.issues == [.tooLong])
        viewModel.draft.text = " Padel on Sundays. "
        #expect(!viewModel.canSubmit, "the same text with spaces around it is no change")
        viewModel.draft.text = ""
        #expect(viewModel.canSubmit, "emptying a written bio clears it")
    }

    @Test func anEmptyFieldOverNoBioHasNothingToSave() async {
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        #expect(viewModel.draft.text.isEmpty && !viewModel.canSubmit)

        viewModel.draft.text = " Football, mostly. "
        #expect(viewModel.canSubmit)
    }

    @Test func aSaveWritesTheTrimmedTextThroughTheStoreAndIsDone() async {
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        viewModel.draft.text = " Football, mostly. "

        await viewModel.submit()

        #expect(repository.updatedBios == ["Football, mostly."] && repository.updatedNames.isEmpty)
        #expect(viewModel.isDone && !viewModel.isSubmitting && errorCenter.current == nil)
        #expect(store.bio == "Football, mostly." && store.displayName == AppConfig.DisplayName.backendDefault)
    }

    @Test func clearingSendsABlankAndTheStoreReadsNoBio() async {
        repository.profileResult = .success(.fixture(bio: "Padel on Sundays."))
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        viewModel.draft.text = ""

        await viewModel.submit()

        #expect(repository.updatedBios == [""] && viewModel.isDone && store.bio == nil)
    }

    /// The sheet can open before the profile answered: `prepare()` loads it and fills the empty field.
    @Test func prepareFillsTheFieldOnceTheBioIsKnown() async {
        repository.profileResult = .success(.fixture(bio: "Padel on Sundays."))
        let viewModel = makeViewModel()
        #expect(viewModel.draft.text.isEmpty)

        await viewModel.prepare()

        #expect(viewModel.draft.text == "Padel on Sundays." && !viewModel.canSubmit)
    }

    /// The sheet opened on the snapshot's bio and the user cleared it before `GET /api/profile` answered: the clear
    /// is an edit, so the answer never puts the bio back.
    @Test func prepareKeepsABioClearedBeforeTheLoadAnswered() async {
        let snapshots = InMemoryListSnapshotStore()
        let snapshotKey = ListSnapshotKey(list: AppConfig.Lists.profileSnapshot, userID: TestFixtures.user.id)
        snapshots.seed(Profile.fixture(bio: "Padel on Sundays."), for: snapshotKey)
        let store = ProfileStore(repository: repository, identity: identity, snapshots: snapshots, logger: logger)
        repository.profileResult = .success(.fixture(bio: "Padel on Sundays."))
        repository.holdsRequests = true
        let viewModel = AboutViewModel(store: store, errorCenter: errorCenter, logger: logger)
        #expect(viewModel.draft.text == "Padel on Sundays.", "the field opens on the snapshot's bio")

        let prepare = Task { await viewModel.prepare() }
        await settle(until: { repository.isHolding })
        viewModel.draft.text = ""
        repository.releaseRequests()
        await prepare.value

        #expect(viewModel.draft.text.isEmpty && viewModel.canSubmit, "the clear survives the answer")
    }

    /// An untouched field opened on the snapshot takes the backend's newer bio once it answers.
    @Test func prepareRefreshesAnUntouchedFieldOpenedOnTheSnapshot() async {
        let snapshots = InMemoryListSnapshotStore()
        let snapshotKey = ListSnapshotKey(list: AppConfig.Lists.profileSnapshot, userID: TestFixtures.user.id)
        snapshots.seed(Profile.fixture(bio: "Padel on Sundays."), for: snapshotKey)
        let store = ProfileStore(repository: repository, identity: identity, snapshots: snapshots, logger: logger)
        repository.profileResult = .success(.fixture(bio: "Football, mostly."))
        let viewModel = AboutViewModel(store: store, errorCenter: errorCenter, logger: logger)

        await viewModel.prepare()

        #expect(viewModel.draft.text == "Football, mostly." && !viewModel.canSubmit)
    }

    @Test func aRefusalReachesThePopupAndKeepsTheDraft() async {
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        viewModel.draft.text = "Something rude"
        repository.updateResult = .failure(AppError.contentRejected)

        await viewModel.submit()

        #expect(errorCenter.current?.error == .contentRejected && !viewModel.isDone)
        #expect(viewModel.draft.text == "Something rude" && viewModel.canSubmit, "Save stays available for a repeat")
        #expect(store.bio == nil)
        #expect(logger.count(in: .auth, at: .error, mentioning: "About update failed") == 1)
    }
}
