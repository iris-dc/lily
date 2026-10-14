import Foundation
import Testing
@testable import lily

/// The language launch arguments; in a file of its own because `AppDependenciesTests` is at the type-body limit. Every
/// test here, and any composition-root test that stores a fixed language, passes a spy `apply`: the real one moves the
/// process-wide `AppLocale`, which the suites asserting English copy read through.
@MainActor
struct AppDependenciesLanguageTests {
    private let defaults = makeTestDefaults()
    private let logger = SpyLogger()

    private var stored: UserDefaultsChoiceStore<LanguagePreference> {
        UserDefaultsChoiceStore(defaults: defaults, logger: logger)
    }

    private func makeLanguageStore(arguments: [String], startsFresh: Bool = false) -> LanguageStore {
        AppDependencies.makeLanguageStore(arguments: arguments,
                                          startsFresh: startsFresh,
                                          defaults: defaults,
                                          logger: logger) { _ in }
    }

    @Test func appLanguageLaunchArgumentShowsTheLanguageForThisRunOnly() {
        stored.save(.fixed(.spanish))

        let language = makeLanguageStore(arguments: [AppConfig.LaunchArguments.appLanguage, "ru"])

        #expect(language.language == .russian)
        #expect(stored.load() == .fixed(.spanish), "a screenshot run leaves the device's choice alone")
    }

    @Test func anUnknownAppLanguageIsIgnoredWithAWarning() {
        let language = makeLanguageStore(arguments: [AppConfig.LaunchArguments.appLanguage, "klingon"])

        let warnings = logger.messages(in: .localization, at: .warning)
        #expect(language.preference == .system)
        #expect(warnings.count == 1 && warnings.first?.contains("klingon") == true)
    }

    /// `-app-language` as the last argument or followed by another flag carries no code; the store's own
    /// "Language <code>" line is not about the flag, so only a launch-argument info line would be wrong here.
    @Test(arguments: [[AppConfig.LaunchArguments.appLanguage],
                      [AppConfig.LaunchArguments.appLanguage, AppConfig.LaunchArguments.mockEvents]])
    func anAppLanguageFlagWithoutAValueIsIgnoredWithAWarning(arguments: [String]) {
        let language = makeLanguageStore(arguments: arguments)

        let warnings = logger.messages(in: .localization, at: .warning)
        #expect(language.preference == .system)
        #expect(warnings.count == 1 && warnings.first?.contains("no value") == true)
        #expect(!logger.messages(in: .localization, at: .info).contains { $0.contains("Launch argument") })
    }

    @Test func resetSessionForgetsTheStoredLanguage() {
        stored.save(.fixed(.polish))

        let language = makeLanguageStore(arguments: [], startsFresh: true)

        #expect(language.preference == .system && stored.load() == .system)
    }

    @Test func aStoredChoiceIsKept() {
        stored.save(.fixed(.french))

        let language = makeLanguageStore(arguments: [])

        #expect(language.preference == .fixed(.french) && language.language == .french)
    }

    @Test func theCompositionRootBuildsTheStoreFromTheArguments() {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents],
                                                       defaults: defaults,
                                                       apply: { _ in })

        #expect(dependencies.language.preference == .system)
    }

    @Test func theCompositionRootForgetsTheStoredLanguageOnAResetSessionLaunch() {
        stored.save(.fixed(.polish))

        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: defaults,
                                                       apply: { _ in })

        #expect(dependencies.language.preference == .system && stored.load() == .system)
    }

    @Test func aStoredFixedLanguageReachesTheCompositionRootThroughTheSpy() {
        stored.save(.fixed(.russian))
        let spy = Spy()

        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents],
                                                       defaults: defaults,
                                                       apply: { spy.applied.append($0) })

        #expect(dependencies.language.language == .russian)
        #expect(spy.applied.map(\.language) == [.russian])
        #expect(AppLocale.current.language == nil, "the process-wide locale stayed where it was")
    }

    @MainActor
    private final class Spy {
        var applied: [AppLocale.Context] = []
    }
}
