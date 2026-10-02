import Foundation
import Testing
@testable import lily

@MainActor
struct AppDependenciesPushTests {
    /// A mock run never meets the permission alert or registers with a backend; the default build does both.
    @Test func mockEventsSelectTheMockRegistrarAndDeviceRepository() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.push.registrar is MockPushRegistrar && mocked.push.devices is MockDeviceRepository)
        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.push.registrar is SystemPushRegistrar && remote.push.devices is RemoteDeviceRepository)
        #expect(AppDependencies.makeMock().push.registrar is MockPushRegistrar)
    }

    /// `-system-push` keeps the real permission prompt and token under mock data, so a banner can be seen on a simulator.
    @Test func systemPushKeepsTheSystemRegistrarUnderMockEvents() {
        let arguments = [AppConfig.LaunchArguments.mockEvents, AppConfig.LaunchArguments.systemPush]
        let dependencies = AppDependencies.makeDefault(arguments: arguments, defaults: makeTestDefaults())
        #expect(dependencies.push.registrar is SystemPushRegistrar && dependencies.push.devices is MockDeviceRepository)
    }

    /// Joining under the mock asks the mock registrar, which grants without an alert, and the device lands in the mock
    /// registry; signing out removes it again.
    @Test func joiningRegistersTheMockDeviceAndSigningOutRemovesIt() async throws {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        let open = try #require(try await dependencies.eventRepository.events(in: .upcoming, near: nil)
            .first { !$0.participates && !$0.isFull })
        let detail = dependencies.makeEventDetailViewModel(for: open) { _ in }

        await detail.join()

        #expect(dependencies.pushCoordinator.registered?.token == AppConfig.Push.mockToken)
        await dependencies.sessionController.signOut()
        #expect(dependencies.pushCoordinator.registered == nil)
    }
}
