/// Whether a settle of the location picker's map is the user's choice of a spot. Pure, so the rule is tested.
nonisolated enum PickerSettlePolicy {
    /// Without a spot the first settle is the map arriving and is skipped; every later one counts, since there is
    /// nothing to measure a move against. With a spot the move is judged, not the count: a settle at least
    /// `minimumMoveMeters` from it is a drag, anything closer is the arrival or a nudge below the map's precision.
    static func isAChoice(_ spot: Coordinate,
                          current: Coordinate?,
                          isFirstSettle: Bool,
                          minimumMoveMeters: Double = AppConfig.Location.pickerMinimumMoveMeters) -> Bool {
        guard let current else { return !isFirstSettle }
        return current.distance(to: spot) >= minimumMoveMeters
    }
}
