import Foundation
import Testing
@testable import lily

/// How the composition root builds the create-event flow for the two places it opens from.
@MainActor
struct AppDependenciesEventFactoryTests {
    /// The create sheet opened from a group is locked to it; from Explore the host chooses.
    @Test func createEventViewModelTakesTheLockedGroup() throws {
        let dependencies = AppDependencies.makeMock()
        let kickers = try #require(MockGroupFixtures.ref(for: MockGroupFixtures.kickersID))

        let locked = dependencies.makeCreateEventViewModel(onCreated: { _ in }, lockedGroup: kickers)
        let free = dependencies.makeCreateEventViewModel(onCreated: { _ in })

        #expect(locked.lockedGroup == kickers && locked.draft.group == kickers)
        #expect(free.lockedGroup == nil && free.draft.group == nil)
    }

    /// `-mock-events-fail` is read only together with `-mock-events`: alone it selects the remote repository.
    @Test func mockEventsFailMakesTheFirstMockLoadFailAndTheDefaultDoesNot() async throws {
        let flags = AppConfig.LaunchArguments.self
        let failing = AppDependencies.makeDefault(arguments: [flags.mockEvents, flags.mockEventsFail],
                                                  defaults: makeTestDefaults())
        let failingEvents = try #require(failing.eventRepository as? MockEventRepository)

        await #expect(throws: AppError.network) { try await failingEvents.events(in: .upcoming, near: nil) }
        #expect(try await failingEvents.events(in: .upcoming, near: nil).isEmpty == false)

        let plain = AppDependencies.makeDefault(arguments: [flags.mockEvents], defaults: makeTestDefaults())
        let plainEvents = try #require(plain.eventRepository as? MockEventRepository)
        #expect(try await plainEvents.events(in: .upcoming, near: nil).isEmpty == false)

        let remote = AppDependencies.makeDefault(arguments: [flags.mockEventsFail], defaults: makeTestDefaults())
        #expect(remote.eventRepository is RemoteEventRepository)
    }
}
