import Foundation

/// List or map, as chosen in the toolbar.
nonisolated enum EventsPresentation: CaseIterable, Hashable, Sendable {
    case list, map

    var title: String {
        switch self {
        case .list: AppBranding.Events.listPresentation
        case .map: AppBranding.Events.mapPresentation
        }
    }

    var symbolName: String {
        switch self {
        case .list: DesignTokens.Symbols.list
        case .map: DesignTokens.Symbols.map
        }
    }

    /// The `presentation` value of a `presentation_changed` interaction; the backend accepts exactly these two.
    var wireValue: String {
        switch self {
        case .list: "list"
        case .map: "map"
        }
    }
}
