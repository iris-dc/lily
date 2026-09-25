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
}
