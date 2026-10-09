import Foundation
import Testing
@testable import lily

/// The currency choice at launch; in a file of its own because `AppDependenciesTests` is at the type-body limit.
@MainActor
struct AppDependenciesCurrencyTests {
    private let defaults = makeTestDefaults()
    private let logger = SpyLogger()

    private var stored: UserDefaultsCurrencyPreferenceStore { UserDefaultsCurrencyPreferenceStore(defaults: defaults) }

    @Test func aStoredChoiceIsKept() {
        stored.save(.fixed("PLN"))

        let currency = AppDependencies.makeCurrencyStore(arguments: [], defaults: defaults, logger: logger)

        #expect(currency.preference == .fixed("PLN") && currency.currencyCode == "PLN")
    }

    @Test func resetSessionForgetsTheStoredCurrency() {
        stored.save(.fixed("PLN"))

        let arguments = [AppConfig.LaunchArguments.resetSession]
        let currency = AppDependencies.makeCurrencyStore(arguments: arguments, defaults: defaults, logger: logger)

        #expect(currency.preference == .system && stored.load() == .system)
    }

    @Test func theCompositionRootHandsTheCurrencyToTheEventScreens() {
        stored.save(.fixed("CHF"))
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: defaults)

        #expect(dependencies.currency.currencyCode == "CHF")
        #expect(dependencies.makeEventListViewModel(scope: .upcoming).priceCurrencyCode == "CHF")
        #expect(dependencies.makeCreateEventViewModel(onCreated: { _ in }).draft.currencyCode == "CHF")
        let free = SportEvent.fixture()
        #expect(dependencies.makeEditEventViewModel(for: free, onChange: { _ in }).draft.currencyCode == "CHF")

        dependencies.currency.select(.fixed("GBP"))

        #expect(dependencies.makeEventListViewModel(scope: .upcoming).priceCurrencyCode == "GBP", "a change applies at once")
    }

    @Test func theMockWiringFollowsTheRegion() {
        let dependencies = AppDependencies.makeMock()

        #expect(dependencies.currency.preference == .system)
    }
}
