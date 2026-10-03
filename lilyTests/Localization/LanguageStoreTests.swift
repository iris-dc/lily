import Foundation
import Testing
@testable import lily

@MainActor
struct LanguageStoreTests {
    @MainActor private final class Harness {
        let store = UserDefaultsLanguagePreferenceStore(defaults: makeTestDefaults())
        let logger = SpyLogger()
        private(set) var applied: [AppLanguage?] = []
        var systemChoice = AppLanguage.english

        func makeStore(launchChoice: AppLanguage? = nil) -> LanguageStore {
            LanguageStore(store: store,
                          launchChoice: launchChoice,
                          systemChoice: { [weak self] in self?.systemChoice ?? .english },
                          apply: { [weak self] in self?.applied.append($0) },
                          logger: logger)
        }
    }

    @Test func startsFromTheStoredChoiceAndAppliesIt() {
        let harness = Harness()
        harness.store.save(.fixed(.polish))

        let store = harness.makeStore()

        #expect(store.preference == .fixed(.polish) && store.language == .polish)
        #expect(harness.applied == [.polish])
        #expect(harness.logger.messages(in: .localization) == ["Language pl (chosen)"])
    }

    @Test func withoutAChoiceItFollowsTheSystem() {
        let harness = Harness()
        harness.systemChoice = .french

        let store = harness.makeStore()

        #expect(store.preference == .system && store.language == .french)
        #expect(harness.applied == [nil])
        #expect(harness.logger.messages(in: .localization) == ["Language fr (system)"])
    }

    @Test func selectingSavesAppliesAndPublishesTheLanguage() {
        let harness = Harness()
        let store = harness.makeStore()

        store.select(.fixed(.ukrainian))

        #expect(store.language == .ukrainian && harness.store.load() == .fixed(.ukrainian))
        #expect(harness.applied == [nil, .ukrainian])
        #expect(harness.logger.messages(in: .localization).last == "Language changed to uk (chosen)")

        store.select(.system)

        #expect(store.language == .english && harness.store.load() == .system)
        #expect(harness.applied == [nil, .ukrainian, nil])
    }

    @Test func selectingTheCurrentChoiceDoesNothing() {
        let harness = Harness()
        let store = harness.makeStore()

        store.select(.system)

        #expect(harness.applied == [nil] && harness.logger.messages(in: .localization).count == 1)
    }

    @Test func aLaunchChoiceIsUsedButNeverStored() {
        let harness = Harness()
        harness.store.save(.fixed(.spanish))

        let store = harness.makeStore(launchChoice: .russian)

        #expect(store.language == .russian && harness.applied == [.russian])
        #expect(harness.store.load() == .fixed(.spanish))
    }

    @Test func theLocaleFollowsTheLanguage() {
        let harness = Harness()
        let store = harness.makeStore()

        store.select(.fixed(.portuguese))

        #expect(store.locale.language.languageCode?.identifier == "pt")
    }
}
