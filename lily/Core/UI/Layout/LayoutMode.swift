import SwiftUI

/// Which layout a screen draws: `compact` is every iPhone and a narrow iPad window (Split View, Slide Over), `regular`
/// an iPad window of regular width, `wide` one wide enough for two panes side by side. Resolved from the size class
/// and the measured width, never from the device, so a window resized under Stage Manager changes layout live.
nonisolated enum LayoutMode: Equatable, Sendable {
    case compact
    case regular
    case wide

    static func resolve(sizeClass: UserInterfaceSizeClass?, width: CGFloat) -> LayoutMode {
        guard sizeClass == .regular else { return .compact }
        return width >= DesignTokens.Layout.wideMinWidth ? .wide : .regular
    }

    /// Whether the screen is at least regular width: the iPad layouts apply.
    var isRegular: Bool { self != .compact }
}

extension EnvironmentValues {
    @Entry var layoutMode: LayoutMode = .compact
}

/// Measures the root's width, reads its size class and publishes the resulting `LayoutMode`, and the width itself as
/// `\.windowWidth`, to every descendant.
private struct LayoutModeProvider: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
            .environment(\.layoutMode, LayoutMode.resolve(sizeClass: sizeClass, width: width))
            .environment(\.windowWidth, width > 0 ? width : nil)
    }
}

extension View {
    /// Goes on the root view once; everything under it reads `\.layoutMode`.
    func layoutModeProvider() -> some View {
        modifier(LayoutModeProvider())
    }
}
