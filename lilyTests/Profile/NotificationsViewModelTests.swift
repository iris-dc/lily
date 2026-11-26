import Foundation
import Testing
@testable import lily

@MainActor
struct NotificationsViewModelTests {
    private let registrar = FakePushRegistrar()
    private let optIn = FakePushOptIn()
    private let pushSync = FakePushSyncing()
    private let logger = SpyLogger()
    private let preferences = NotificationPreferences(defaults: makeTestDefaults())

    private func makeViewModel() -> NotificationsViewModel {
        NotificationsViewModel(registrar: registrar,
                               preferences: preferences,
                               optIn: optIn,
                               pushSync: pushSync,
                               logger: logger)
    }

    @Test func refreshReadsTheSystemsAnswer() async {
        registrar.status = .denied
        let viewModel = makeViewModel()
        #expect(viewModel.authorization == nil, "a spinner until the first read answers")

        await viewModel.refresh()

        #expect(viewModel.authorization == .denied)
    }

    @Test func enableOffersThePromptOnceAndRereadsTheStatus() async {
        registrar.status = .authorized
        let viewModel = makeViewModel()

        await viewModel.enable()

        #expect(optIn.offerCount == 1 && viewModel.authorization == .authorized)
    }

    /// A flip persists on the device, logs, and asks the coordinator to re-register; a repeat of the same value is
    /// dropped, so a settling `Toggle` binding never syncs twice.
    @Test func aFlipPersistsAndAsksForASync() async {
        let viewModel = makeViewModel()

        viewModel.set(.eventReminder, enabled: false)
        await viewModel.syncTask?.value
        viewModel.set(.eventReminder, enabled: false)
        await viewModel.syncTask?.value

        #expect(preferences.mutedWireNames == ["event_reminder"])
        #expect(!viewModel.isEnabled(.eventReminder))
        #expect(pushSync.syncCount == 1)
        #expect(logger.messages(in: .push, at: .info).mentioning("event_reminder", "muted").count == 1)
    }

    @Test func flippingBackEnablesAndSyncsAgain() async {
        let viewModel = makeViewModel()

        viewModel.set(.matchReminder, enabled: false)
        await viewModel.syncTask?.value
        viewModel.set(.matchReminder, enabled: true)
        await viewModel.syncTask?.value

        #expect(preferences.mutedWireNames.isEmpty && viewModel.isEnabled(.matchReminder))
        #expect(pushSync.syncCount == 2)
    }
}
