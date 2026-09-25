import Foundation
import Testing
@testable import lily

@MainActor
struct JoinWithCodeViewModelTests {
    private let harness = GroupHarness()
    private let viewModel: JoinWithCodeViewModel

    init() {
        let harness = self.harness
        viewModel = JoinWithCodeViewModel { code in
            InvitePreviewViewModel(code: code,
                                   invites: harness.invites,
                                   groups: harness.repository,
                                   identity: harness.identity,
                                   store: harness.store,
                                   navigation: harness.navigation,
                                   reporter: harness.reporter,
                                   logger: harness.logger,
                                   tryAgainDelay: .zero,
                                   onJoined: harness.sink.record)
        }
    }

    @Test func theInputFormatsItselfAsTyped() {
        viewModel.input = "krzb 7k3m"
        #expect(viewModel.input == "KRZB-7K3M" && !viewModel.canContinue)

        viewModel.input = "krzb-7k3m-qx9p"
        #expect(viewModel.input == "KRZB-7K3M-QX9P" && viewModel.canContinue)
        #expect(viewModel.code?.value == AppConfig.Groups.mockInviteCode)
    }

    @Test func lookAlikesAreMappedAndExtraSymbolsDropped() {
        viewModel.input = "oi"
        #expect(viewModel.input == "01")

        viewModel.input = AppConfig.Groups.mockInviteCode + "ZZZZ"
        #expect(viewModel.input == "KRZB-7K3M-QX9P")
    }

    @Test func proceedNeedsACompleteCode() async {
        viewModel.input = "ABC"

        await viewModel.proceed()

        #expect(viewModel.preview == nil && harness.invites.previewedCodes.isEmpty)
    }

    @Test func proceedPreviewsTheCodeAndEditGoesBackToTheField() async {
        harness.invites.previewResult = .success(.fixture())
        viewModel.input = AppConfig.Groups.mockInviteCode

        await viewModel.proceed()

        #expect(viewModel.preview?.groupName == "Climbing Buddies")
        #expect(harness.invites.previewedCodes.map(\.value) == [AppConfig.Groups.mockInviteCode])

        viewModel.editCode()
        #expect(viewModel.preview == nil && viewModel.input == "KRZB-7K3M-QX9P")
    }
}
