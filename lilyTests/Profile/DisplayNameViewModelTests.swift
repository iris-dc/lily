import Foundation
import Testing
@testable import lily

/// The display name editor's model: Save only for a changed valid name, the store's name replaced by the answer, a
/// refusal shown and the draft kept, a cancellation quiet.
@MainActor
struct DisplayNameViewModelTests {
    private let repository = FakeProfileRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter
    private let store: ProfileStore

    init() {
        errorCenter = ErrorCenter(logger: logger)
        store = ProfileStore(repository: repository, identity: identity, snapshots: InMemoryListSnapshotStore(), logger: logger)
    }

    private func makeViewModel() -> DisplayNameViewModel {
        DisplayNameViewModel(store: store, errorCenter: errorCenter, logger: logger)
    }

    @Test func saveIsOffUntilTheNameChangesAndIsValid() async {
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        #expect(viewModel.draft.name == AppConfig.DisplayName.backendDefault, "the field starts from the store's name")
        #expect(!viewModel.canSubmit, "nothing to save until something changed")

        viewModel.draft.name = "   "
        #expect(!viewModel.canSubmit && viewModel.issues == [.nameMissing])
        viewModel.draft.name = String(repeating: "x", count: AppConfig.DisplayName.length.upperBound + 1)
        #expect(!viewModel.canSubmit && viewModel.issues == [.nameTooLong])
        viewModel.draft.name = " Alex Kim "
        #expect(viewModel.canSubmit && viewModel.issues.isEmpty)
        viewModel.draft.name = " \(AppConfig.DisplayName.backendDefault) "
        #expect(!viewModel.canSubmit, "the same name with spaces around it is no change")
    }

    @Test func aSaveRenamesThroughTheStoreAndIsDone() async {
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        viewModel.draft.name = " Alex Kim "

        await viewModel.submit()

        #expect(repository.updatedNames == ["Alex Kim"], "the trimmed name is what goes out")
        #expect(viewModel.isDone && !viewModel.isSubmitting && errorCenter.current == nil)
        #expect(store.displayName == "Alex Kim")
    }

    /// The sheet can open before the profile answered: `prepare()` loads it and fills the empty field.
    @Test func prepareFillsTheFieldOnceTheNameIsKnown() async {
        repository.profileResult = .success(.fixture(displayName: "Alex Kim"))
        let viewModel = makeViewModel()
        #expect(viewModel.draft.name.isEmpty)

        await viewModel.prepare()

        #expect(viewModel.draft.name == "Alex Kim" && !viewModel.canSubmit, "the loaded name is the one to change")
    }

    @Test func prepareKeepsWhatTheUserTypedMeanwhile() async {
        repository.profileResult = .success(.fixture(displayName: "Alex Kim"))
        repository.holdsRequests = true
        let viewModel = makeViewModel()

        let preparing = Task { await viewModel.prepare() }
        await settle(until: { store.isLoading })
        viewModel.draft.name = "Sam"
        repository.releaseRequests()
        await preparing.value

        #expect(viewModel.draft.name == "Sam" && store.displayName == "Alex Kim" && viewModel.canSubmit)
    }

    /// The user typed the very name the slow load then answered: nothing changed, so there is nothing to save.
    @Test func typingTheLoadedNameBeforeTheLoadAnsweredIsNoChange() async {
        repository.profileResult = .success(.fixture(displayName: "Alex Kim"))
        repository.holdsRequests = true
        let viewModel = makeViewModel()

        let preparing = Task { await viewModel.prepare() }
        await settle(until: { store.isLoading })
        viewModel.draft.name = "Alex Kim"
        #expect(viewModel.canSubmit, "a name the store does not know yet is a change")
        repository.releaseRequests()
        await preparing.value

        #expect(viewModel.draft.name == "Alex Kim" && !viewModel.canSubmit, "the draft equals the loaded name")
    }

    /// A lost answer after the backend stored the name: the store reads it back, the sheet closes, no popup.
    @Test func aLostAnswerWhoseNameLandedClosesTheSheetWithoutAPopup() async {
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        viewModel.draft.name = "Alex Kim"
        repository.updateResult = .failure(AppError.network)
        repository.profileResult = .success(.fixture(displayName: "Alex Kim"))

        await viewModel.submit()

        #expect(viewModel.isDone && errorCenter.current == nil && store.displayName == "Alex Kim")
    }

    @Test func aRefusalReachesThePopupAndKeepsTheDraft() async {
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        viewModel.draft.name = "Something rude"
        repository.updateResult = .failure(AppError.contentRejected)

        await viewModel.submit()

        #expect(errorCenter.current?.error == .contentRejected && !viewModel.isDone)
        #expect(viewModel.draft.name == "Something rude" && viewModel.canSubmit, "Save stays available for a repeat")
        #expect(store.displayName == AppConfig.DisplayName.backendDefault)
        #expect(logger.count(in: .auth, at: .error, mentioning: "Display name update failed") == 1)
    }

    @Test func aCancelledSaveStaysQuiet() async {
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        viewModel.draft.name = "Alex Kim"
        repository.updateResult = .failure(CancellationError())

        await viewModel.submit()

        #expect(errorCenter.current == nil && !viewModel.isDone)
        #expect(logger.messages(in: .auth, at: .error).isEmpty)
    }

    @Test func aSecondSubmitWhileOneIsInFlightIsDropped() async {
        await store.loadIfNeeded()
        let viewModel = makeViewModel()
        viewModel.draft.name = "Alex Kim"
        repository.holdsRequests = true

        let first = Task { await viewModel.submit() }
        await settle(until: { viewModel.isSubmitting })
        #expect(!viewModel.canSubmit)
        await viewModel.submit()
        #expect(repository.updatedNames.count == 1, "the repeat is dropped rather than sent twice")

        repository.releaseRequests()
        await first.value
        #expect(viewModel.isDone && !viewModel.isSubmitting)
    }
}
