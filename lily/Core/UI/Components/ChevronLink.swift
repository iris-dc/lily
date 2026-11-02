import SwiftUI

/// A line of text that leads somewhere (the host under an event's title, "Hosted in <group>"): the label in `.secondary`
/// with a small chevron after it as the link's cue, pushing `value` on the stack it is in. The colour is never the cue:
/// the accent reads at about 3:1 as small text over the aurora.
struct ChevronLink<Value: Hashable, Label: View>: View {
    let value: Value
    @ViewBuilder let label: () -> Label

    var body: some View {
        NavigationLink(value: value) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                label()
                Image(systemName: DesignTokens.Symbols.chevron)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ContentScreen {
            ChevronLink(value: "marta") {
                Text("Hosted by Marta").font(.subheadline)
            }
        }
    }
}
