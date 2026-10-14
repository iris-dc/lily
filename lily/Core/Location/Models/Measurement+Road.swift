import Foundation

nonisolated extension Measurement where UnitType == UnitLength {
    /// Road-style distance ("1,6 km", "800 m") in the given locale's language and units, the app's by default, as
    /// shown on cards and in the filter panel's distance choice. The default is read per call, so it follows a
    /// language or Region change like `Price.text` and `FileCardInfo.sizeText` do.
    func roadText(locale: Locale = AppLocale.locale) -> String {
        formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }
}
