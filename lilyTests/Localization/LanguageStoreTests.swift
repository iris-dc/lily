import Foundation
import Testing
@testable import lily

@MainActor
struct LanguageStoreTests {
    @MainActor private final class Harness {
        let store = UserDefaultsChoiceStore<LanguagePreference>(defaults: makeTestDefaults(), logger: SpyLogger())
        let logger = SpyLogger()
        private(set) var applied: [AppLocale.Context] = []
        var systemChoice = AppLanguage.english

        func makeStore(launchChoice: AppLanguage? = nil) -> LanguageStore {
            LanguageStore(store: store,
                          launchChoice: launchChoice,
                          systemChoice: { [weak self] in self?.systemChoice ?? .english },
                          apply: { [weak self] in self?.applied.append($0) },
                          logger: logger)
        }

        /// The languages of the contexts applied so far, in order (`nil` is the system's choice).
        var appliedLanguages: [AppLanguage?] { applied.map(\.language) }

        var infoLines: [String] { logger.messages(in: .localization, at: .info) }
    }

    @Test func startsFromTheStoredChoiceAndAppliesIt() {
        let harness = Harness()
        harness.store.save(.fixed(.polish))

        let store = harness.makeStore()

        #expect(store.preference == .fixed(.polish) && store.language == .polish)
        #expect(harness.appliedLanguages == [.polish])
        let lines = harness.infoLines
        #expect(lines.count == 1)
        #expect(lines.last?.contains("pl") == true && lines.last?.contains("chosen") == true)
    }

    @Test func withoutAChoiceItFollowsTheSystem() {
        let harness = Harness()
        harness.systemChoice = .french

        let store = harness.makeStore()

        #expect(store.preference == .system && store.language == .french)
        #expect(harness.appliedLanguages == [nil])
        let lines = harness.infoLines
        #expect(lines.count == 1)
        #expect(lines.last?.contains("fr") == true && lines.last?.contains("system") == true)
    }

    @Test func selectingSavesAppliesAndPublishesTheLanguage() {
        let harness = Harness()
        let store = harness.makeStore()

        store.select(.fixed(.ukrainian))

        #expect(store.language == .ukrainian && harness.store.load() == .fixed(.ukrainian))
        #expect(harness.appliedLanguages == [nil, .ukrainian])
        let lines = harness.infoLines
        #expect(lines.count == 2)
        #expect(lines.last?.contains("uk") == true && lines.last?.contains("chosen") == true)

        store.select(.system)

        #expect(store.language == .english && harness.store.load() == .system)
        #expect(harness.appliedLanguages == [nil, .ukrainian, nil])
    }

    @Test func selectingTheCurrentChoiceDoesNothing() {
        let harness = Harness()
        let store = harness.makeStore()

        store.select(.system)

        #expect(harness.appliedLanguages == [nil] && harness.infoLines.count == 1)
    }

    @Test func aLaunchChoiceIsUsedButNeverStored() {
        let harness = Harness()
        harness.store.save(.fixed(.spanish))

        let store = harness.makeStore(launchChoice: .russian)

        #expect(store.language == .russian && harness.appliedLanguages == [.russian])
        #expect(harness.store.load() == .fixed(.spanish))
    }

    @Test func theLocaleFollowsTheLanguage() {
        let harness = Harness()
        let store = harness.makeStore()

        store.select(.fixed(.portuguese))

        #expect(store.locale.language.languageCode?.identifier == "pt")
        #expect(harness.applied.last?.language == .portuguese)
        #expect(store.locale.identifier == harness.applied.last?.locale.identifier)
    }
}
