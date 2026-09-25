import SwiftUI

/// A day boundary in the chat: "Today", "Yesterday" or the date, centred in a small glass chip.
struct DaySeparator: View {
    let day: Date
    var now: Date = .now

    var body: some View {
        Text(ChatDayLabel.text(for: day, now: now))
            .foregroundStyle(.secondary)
            .lilyChip(.regular)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

#Preview {
    ContentScreen {
        VStack {
            DaySeparator(day: .now)
            DaySeparator(day: .now.addingTimeInterval(-86_400))
            DaySeparator(day: .now.addingTimeInterval(-86_400 * 9))
        }
    }
}
