import Foundation

nonisolated extension Measurement where UnitType == UnitLength {
    /// Road-style distance ("1,6 km", "800 m") in the user's locale, as shown on cards and in the filter panel's distance choice.
    var roadText: String {
        formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
