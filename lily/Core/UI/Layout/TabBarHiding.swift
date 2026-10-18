import Observation
import SwiftUI

/// The screens of one navigation stack that hide the tab bar, each by its depth in the stack. A pushed screen's own
/// visibility leaves with the screen the moment a pop starts, so the bar would reappear in one frame; the stack's root
/// reads this instead and flips the bar inside an animation as the path changes, which is what makes the bar slide
/// away and back with the push and the pop.
@Observable
final class TabBarHiding {
    /// The depth of every screen on this stack that hides the bar, by the screen's own token, so two screens at one
    /// depth (one replacing the other) do not cancel each other out.
    private var depths: [AnyHashable: Int] = [:]

    /// Registers the screen at its depth, once: a screen appearing again after the pop of what covered it may read a
    /// stale depth, and its place in the stack has not changed.
    func hide(_ token: AnyHashable, at depth: Int) {
        if depths[token] == nil {
            depths[token] = depth
        }
    }

    /// Forgets every screen deeper than `depth`, the ones a shrinking path popped; a screen covered by a push keeps
    /// its place, so the bar hides again when the cover is popped.
    func prune(above depth: Int) {
        depths = depths.filter { $0.value <= depth }
    }

    /// Whether the screen at `depth` hides the bar.
    func hides(at depth: Int) -> Bool {
        depths.values.contains(depth)
    }
}

extension EnvironmentValues {
    /// The registry of the stack a screen is pushed on; `nil` on a stack whose root does not animate the bar.
    @Entry var tabBarHiding: TabBarHiding?
    /// The number of screens pushed on the stack a screen is in: its own depth while it is the top.
    @Entry var navigationDepth = 0
}

/// Goes on a `NavigationStack` bound to a path: owns the tab bar's visibility for the whole stack and animates it
/// whenever the top screen's wish (`hidesTabBarOnCompact()`) or the width changes. The bar never hides on a regular
/// width, where the screen sits under the tabs' top bar. The path is only ever appended to or shrunk, never replaced
/// at the same count, which is what lets a registration stand for the screen at its depth.
private struct AnimatesTabBar: ViewModifier {
    let depth: Int
    @Environment(\.layoutMode) private var layoutMode
    @State private var hiding = TabBarHiding()
    @State private var isHidden = false

    func body(content: Content) -> some View {
        content
            .toolbarVisibility(isHidden ? .hidden : .automatic, for: .tabBar)
            .environment(\.tabBarHiding, hiding)
            .environment(\.navigationDepth, depth)
            .onChange(of: depth) { _, depth in hiding.prune(above: depth) }
            .onChange(of: hiding.hides(at: depth) && !layoutMode.isRegular, initial: true) { _, hides in
                withAnimation(.easeInOut(duration: DesignTokens.Duration.normal)) { isHidden = hides }
            }
    }
}

extension View {
    /// `depth` is the bound path's count; a stack without one cannot tell which screen is on top.
    func animatesTabBar(depth: Int) -> some View {
        modifier(AnimatesTabBar(depth: depth))
    }
}
