import Foundation

nonisolated extension Measurement where UnitType == UnitLength {
    /// Road-style distance ("1,6 km", "800 m") in the locale's language and units, the app's by default; the default is
    /// read per call, so it follows a language or Region change.
    func roadText(locale: Locale = AppLocale.locale) -> String {
        formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }
}
