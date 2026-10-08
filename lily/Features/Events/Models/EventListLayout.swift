import Foundation

/// How the events screen is composed at a layout mode: one column with a list/map switch, or, when the window is wide
/// and the screen has a map at all, the content column beside a map that is always there.
nonisolated enum EventListLayout: Equatable, Sendable {
    /// The list or the map, chosen by the toolbar's picker.
    case switchable
    /// The content column on the left and the map pane on the right; the picker is gone.
    case sideBySide

    static func resolve(mode: LayoutMode, showsMap: Bool) -> EventListLayout {
        mode == .wide && showsMap ? .sideBySide : .switchable
    }
}
