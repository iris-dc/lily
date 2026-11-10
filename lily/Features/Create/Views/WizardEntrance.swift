import SwiftUI

/// Eases a step's content in on entry: a short slide up with a fade, re-run on every entry (push and pop-return
/// alike). Movement follows the motion preference — reduced motion keeps the fade in place and drops the slide.
private struct WizardEntrance: ViewModifier {
    @Environment(\.motion) private var motion
    @State private var hasEntered = false

    func body(content: Content) -> some View {
        content
            .opacity(hasEntered ? 1 : 0)
            .offset(y: hasEntered || !motion.allowsMovement ? 0 : DesignTokens.Layout.wizardEntranceOffset)
            .onAppear {
                withAnimation(.easeOut(duration: DesignTokens.Duration.fast)) { hasEntered = true }
            }
            .onDisappear { hasEntered = false }
    }
}

extension View {
    /// The wizard pages' entrance, on the step scaffold's content under the progress mark.
    func wizardEntrance() -> some View {
        modifier(WizardEntrance())
    }
}
