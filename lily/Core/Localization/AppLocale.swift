import Foundation
import Synchronization

/// The language the copy is read in and the locale its numbers, dates and plural rules follow, for the whole process.
/// `LanguageStore` sets it; `localized(_:)` and every formatter read it. A static, because copy is read from
/// `nonisolated` types (`AppBranding`, `ErrorMessageMapper`, the models) that have no way to an instance.
nonisolated enum AppLocale {
    /// What one choice of language means for lookups: the `.lproj` copy is read from (the main bundle while the system
    /// chooses, so iOS applies the user's preferred languages and its fallback to English) and the locale formats follow.
    struct Context: Sendable {
        /// The fixed language, `nil` while the system chooses.
        let language: AppLanguage?
        private let bundlePath: String?
        private let current: @Sendable () -> Locale

        /// `Bundle(path:)` hands back the one instance it already made for a path, so this is a lookup, not a load.
        var bundle: Bundle {
            bundlePath.flatMap(Bundle.init(path:)) ?? .main
        }

        /// Derived on every read, so a Region change in Settings reaches prices and distances without a relaunch: the
        /// system path hands back the live `.autoupdatingCurrent` itself, the fixed path rebuilds its components from it
        /// (cheap: Foundation serves `Locale(components:)` from its identifier cache).
        var locale: Locale {
            language.map { Self.locale(for: $0, current: current()) } ?? current()
        }

        /// A language whose `.lproj` the build does not carry reads from the main bundle, like the system choice.
        init(language: AppLanguage?,
             mainBundle: Bundle = .main,
             current: @escaping @Sendable () -> Locale = { .autoupdatingCurrent }) {
            self.language = language
            self.current = current
            bundlePath = language.flatMap { mainBundle.path(forResource: $0.code, ofType: Self.localizationFolderExtension) }
        }

        /// The language with everything else of `current` kept (region, calendar, hour cycle, units), so a Russian
        /// reader in the US still sees their dates and distances the local way. `current` is passed per read, never
        /// defaulted: a `Locale` argument is a snapshot, and a default here would freeze the region at the first call.
        static func locale(for language: AppLanguage, current: Locale) -> Locale {
            var components = Locale.Components(locale: current)
            components.languageComponents.languageCode = Locale.LanguageCode(language.code)
            components.languageComponents.script = nil
            return Locale(components: components)
        }

        private static let localizationFolderExtension = "lproj"
    }

    private static let state = Mutex(Context(language: nil))

    static var current: Context {
        state.withLock { $0 }
    }

    /// The bundle copy is read from.
    static var bundle: Bundle { current.bundle }

    /// The locale numbers, dates and plural rules follow.
    static var locale: Locale { current.locale }

    /// `LanguageStore` builds the context for its choice and sets it here (a `nil` language lets the system choose
    /// again). Views re-render from `LanguageStore`, not from here.
    static func set(_ context: Context) {
        state.withLock { $0 = context }
    }
}
