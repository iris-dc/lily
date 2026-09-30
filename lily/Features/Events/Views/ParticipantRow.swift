import SwiftUI

/// One person in a game's "Who's in" list: their mark, their name ("You" for the caller) and a "Host" chip on the
/// host's row. Every row but the caller's own opens the person's profile.
struct ParticipantRow: View {
    let participant: EventParticipant
    let isSelf: Bool

    var body: some View {
        PersonRow(userID: participant.userId,
                  displayName: participant.displayName,
                  isSelf: isSelf,
                  identifier: AccessibilityIdentifiers.participantRow(participant.userId)) {
            if participant.isHost {
                Text(AppBranding.Events.hostChip)
                    .lilyChip(.regular)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ContentScreen {
            VStack {
                ParticipantRow(participant: EventParticipant(userId: "u-2", displayName: "Marta", joinedAt: .now, isHost: true),
                               isSelf: false)
                ParticipantRow(participant: EventParticipant(userId: "u-1", displayName: "You", joinedAt: .now, isHost: false),
                               isSelf: true)
            }
            .padding()
        }
    }
}
