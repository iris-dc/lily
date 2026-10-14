import Foundation
import Testing
@testable import lily

@MainActor
struct EditEventViewModelTests {
    nonisolated private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private let repository = FakeEventRepository()
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter
    private let changed = Recorded<SportEvent>()
    private let event: SportEvent
    private let viewModel: EditEventViewModel

    init() {
        errorCenter = ErrorCenter(logger: logger)
        event = SportEvent.fixture(id: "e",
                                   title: "Old title",
                                   capacity: 4,
                                   participants: 3,
                                   startsAt: Self.now.addingTimeInterval(3600),
                                   hostUserId: "host",
                                   isJoined: true)
        repository.result = .success([event])
        viewModel = EditEventViewModel(event: event,
                                       repository: repository,
                                       errorCenter: errorCenter,
                                       logger: logger,
                                       tryAgainDelay: .zero,
                                       now: { Self.now },
                                       currencyCode: EventDraft.testCurrencyCode,
                                       onChange: changed.record)
    }

    /// A price added to a game that had none is in the user's currency; a priced game keeps the currency it was
    /// created in, whatever the user's is now, and an untouched draft still counts as unchanged.
    @Test func aNewPriceTakesTheUsersCurrencyAndAnExistingOneKeepsItsOwn() {
        let polish = EditEventViewModel(event: event,
                                        repository: repository,
                                        errorCenter: errorCenter,
                                        logger: logger,
                                        tryAgainDelay: .zero,
                                        now: { Self.now },
                                        currencyCode: "PLN",
                                        onChange: changed.record)
        #expect(!polish.hasChanges)
        polish.draft.price = 40
        #expect(polish.hasChanges && polish.draft.eventPrice == Price(amount: 40, currencyCode: "PLN"))

        let priced = SportEvent.fixture(id: "p", hostUserId: "host", price: Price(amount: 5, currencyCode: "EUR"))
        let euro = EditEventViewModel(event: priced,
                                      repository: repository,
                                      errorCenter: errorCenter,
                                      logger: logger,
                                      tryAgainDelay: .zero,
                                      now: { Self.now },
                                      currencyCode: "PLN",
                                      onChange: changed.record)
        #expect(!euro.hasChanges && euro.draft.currencyCode == "EUR")
        euro.draft.price = 7
        #expect(euro.draft.eventPrice == Price(amount: 7, currencyCode: "EUR"))
    }

    @Test func startsFromTheEventWithNothingToSave() {
        #expect(viewModel.draft.title == "Old title" && viewModel.draft.clientId == "e")
        #expect(!viewModel.hasChanges && !viewModel.canSubmit && !viewModel.isDone)
        #expect(viewModel.issues.isEmpty)
        #expect(viewModel.capacityRange.lowerBound == 3, "the three already in are the floor")
        #expect(viewModel.earliestStart == Self.now.addingTimeInterval(AppConfig.Events.Editing.startMargin),
                "an edit's start is held the request margin ahead, not a create's quarter hour")
        #expect(!viewModel.showsGroupRow && viewModel.lockedGroup == nil)
    }

    @Test func aGroupedGameShowsItsGroupReadOnly() {
        let kickers = EventGroupRef(id: "kickers", name: "Kreuzberg Kickers", visibility: .public, isDeleted: false)
        var draft = EventDraft.fixture(now: Self.now)
        draft.group = kickers
        let grouped = draft.makeEvent(hostUserId: "host", hostName: "h", coordinate: AppConfig.Location.mockCenter)

        let viewModel = EditEventViewModel(event: grouped,
                                           repository: repository,
                                           errorCenter: errorCenter,
                                           logger: logger,
                                           now: { Self.now },
                                           currencyCode: EventDraft.testCurrencyCode,
                                           onChange: changed.record)

        #expect(viewModel.showsGroupRow && viewModel.lockedGroup == kickers)
        #expect(viewModel.eligibleGroups.isEmpty && !viewModel.explainsNoEligibleGroups)
    }

    @Test func submitSavesTheChangesAndHandsThemOn() async {
        viewModel.draft.title = "New title"
        viewModel.draft.capacity = 6
        #expect(viewModel.hasChanges && viewModel.canSubmit)

        await viewModel.submit()

        #expect(viewModel.updatedEvent?.title == "New title" && viewModel.updatedEvent?.capacity == 6)
        #expect(viewModel.isDone)
        #expect(changed.values.map(\.title) == ["New title"])
        #expect(repository.updatedDrafts.map(\.id) == ["e"])
        #expect(logger.count(in: .events, at: .info) == 1)
        #expect(logger.hasLine(in: .events, at: .info, mentioning: "e updated", "6 spots"))
    }

    @Test func fewerSpotsThanPeopleInCannotBeSaved() {
        viewModel.draft.capacity = 2

        #expect(viewModel.hasChanges && !viewModel.canSubmit)
        #expect(viewModel.issue(for: .capacityOutOfRange, .capacityBelowParticipants) == .capacityBelowParticipants)
    }

    /// The edit rules want only the request margin: a game about to start can still be edited without moving it.
    @Test func aStartJustAheadIsAccepted() {
        viewModel.draft.startsAt = Self.now.addingTimeInterval(AppConfig.Events.Editing.startMargin)

        #expect(viewModel.canSubmit)
    }

    /// Inside the margin the backend could refuse the start by the time the request lands, so Save waits.
    @Test func aStartWithinTheMarginHoldsSave() {
        viewModel.draft.startsAt = Self.now.addingTimeInterval(AppConfig.Events.Editing.startMargin - 1)

        #expect(!viewModel.canSubmit)
        #expect(viewModel.issues == [.startsAtTooSoon])
    }

    /// The backend refuses an edit when another one landed since its pre-read; the same request then goes through.
    @Test func aLostRaceIsRepeatedOnce() async {
        viewModel.draft.title = "New title"
        repository.nextUpdateError = AppError.tryAgain

        await viewModel.submit()

        #expect(viewModel.updatedEvent?.title == "New title")
        #expect(repository.updatedDrafts.count == 2)
        #expect(logger.hasLine(in: .events, at: .info, mentioning: "event e", "lost a race"))
        #expect(errorCenter.current == nil)
    }

    @Test func aFailureReachesThePopupAndKeepsTheSheetOpen() async {
        viewModel.draft.title = "New title"
        repository.updateError = AppError.notHost

        await viewModel.submit()

        #expect(viewModel.updatedEvent == nil && !viewModel.isDone)
        #expect(errorCenter.current?.error == .notHost)
        #expect(changed.values.isEmpty)
        #expect(logger.messages(in: .events, at: .error).count == 1)
    }

    @Test func cancellationStaysQuiet() async {
        viewModel.draft.title = "New title"
        repository.updateError = CancellationError()

        await viewModel.submit()

        #expect(errorCenter.current == nil && logger.entries.isEmpty)
    }

    @Test func aSecondSubmitWhileTheFirstIsInFlightIsDropped() async {
        viewModel.draft.title = "New title"
        repository.holdsRequests = true

        let first = Task { await viewModel.submit() }
        await settle(until: { repository.updatedDrafts.count == 1 })
        await viewModel.submit()
        repository.releaseRequests()
        await first.value

        #expect(repository.updatedDrafts.count == 1)
        #expect(changed.values.count == 1)
    }
}
