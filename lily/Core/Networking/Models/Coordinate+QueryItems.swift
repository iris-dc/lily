import Foundation

nonisolated extension Coordinate {
    /// `lat` and `lon` of the `coarse` position, printed with exactly `AppConfig.Events.positionPrecision` decimals and
    /// a `.` whatever the locale: `"\(double)"` could print `52.540000000000006` or an exponent.
    var queryItems: [URLQueryItem] {
        let position = coarse
        let format = "%.\(AppConfig.Events.positionPrecision)f"
        return [URLQueryItem(name: AppConfig.API.Query.latitude, value: String(format: format, position.latitude)),
                URLQueryItem(name: AppConfig.API.Query.longitude, value: String(format: format, position.longitude))]
    }
}
