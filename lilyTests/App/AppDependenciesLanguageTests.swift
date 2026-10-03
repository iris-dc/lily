import Foundation
import Testing
@testable import lily

/// The language launch arguments; in a file of its own because `AppDependenciesTests` is at the type-body limit. The
/// store is built with a no-op `apply`: the real one moves the process-wide `AppLocale`, which the suites running
/// alongside read their English copy through.
@MainActor
struct AppDependenciesLanguageTests {
    private let defaults = makeTestDefaults()
    private let logger = SpyLogger()

    private var stored: UserDefaultsLanguagePreferenceStore { UserDefaultsLanguagePreferenceStore(defaults: defaults) }

    private func makeLanguageStore(arguments: [String]) -> LanguageStore {
        AppDependencies.makeLanguageStore(arguments: arguments, defaults: defaults, logger: logger) { _ in }
    }

    @Test func appLanguageLaunchArgumentShowsTheLanguageForThisRunOnly() {
        stored.save(.fixed(.spanish))

        let language = makeLanguageStore(arguments: [AppConfig.LaunchArguments.appLanguage, "ru"])

        #expect(language.language == .russian)
        #expect(stored.load() == .fixed(.spanish), "a screenshot run leaves the device's choice alone")
    }

    @Test func anUnknownAppLanguageIsIgnoredWithAWarning() {
        let language = makeLanguageStore(arguments: [AppConfig.LaunchArguments.appLanguage, "klingon"])

        #expect(language.preference == .system)
        #expect(logger.messages(in: .localization, at: .warning).count == 1)
    }

    @Test func resetSessionForgetsTheStoredLanguage() {
        stored.save(.fixed(.polish))

        let language = makeLanguageStore(arguments: [AppConfig.LaunchArguments.resetSession])

        #expect(language.preference == .system && stored.load() == .system)
    }

    @Test func aStoredChoiceIsKept() {
        stored.save(.fixed(.french))

        let language = makeLanguageStore(arguments: [])

        #expect(language.preference == .fixed(.french) && language.language == .french)
    }

    @Test func theCompositionRootBuildsTheStoreFromTheArguments() {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: defaults)

        #expect(dependencies.language.preference == .system)
    }
}
