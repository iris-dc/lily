import SwiftUI

/// The step indicator as an animated mark: a capsule track whose accent fill grows to the current step's share on
/// entry, starting from the previous step's, so entering a step is seen filling the difference. The plural-safe
/// "Step n of m" stays as the accessibility label; the fill moves only while the motion preference allows movement
/// and otherwise sits at its share.
struct WizardProgressBar: View {
    /// Counting from one.
    let number: Int
    let count: Int
    @Environment(\.motion) private var motion
    @State private var hasFilled = false

    var body: some View {
        Capsule()
            .fill(Color.lilyInk.opacity(DesignTokens.Opacity.wizardProgressTrack))
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(Color.lilyAccent)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: DesignTokens.Layout.wizardProgressBarHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AppBranding.Create.step(number, of: count))
            .onAppear { fill() }
            .onDisappear { hasFilled = false }
    }

    /// The share drawn: the previous step's until the entry animation runs, so a pop-return fills again too.
    private var fraction: CGFloat {
        let reached = hasFilled ? number : number - 1
        return CGFloat(max(reached, 0)) / CGFloat(max(count, 1))
    }

    private func fill() {
        guard motion.allowsMovement else {
            hasFilled = true
            return
        }
        withAnimation(.smooth(duration: DesignTokens.Duration.normal)) { hasFilled = true }
    }
}
