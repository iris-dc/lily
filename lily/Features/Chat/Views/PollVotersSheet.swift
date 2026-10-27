import SwiftUI

/// Who voted for what in a public poll: a section per option, its count at the trailing edge, with its voters in the
/// order they voted, each behind their initials. A failed load closes the sheet and reaches the popup under it.
struct PollVotersSheet: View {
    let message: ChatMessage
    let viewModel: ChatViewModel
    let errorCenter: ErrorCenter
    @State private var voters: PollVoters?
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Chat.Polls

    var body: some View {
        NavigationStack {
            ContentScreen {
                List {
                    ForEach(message.poll?.options ?? []) { option in
                        Section {
                            section(for: option)
                        } header: {
                            HStack {
                                Text(verbatim: option.text)
                                Spacer()
                                Text(count(for: option), format: .number)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .readableColumn()
                .overlay { if voters == nil { ProgressView() } }
            }
            .navigationTitle(Copy.votes)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppBranding.done) { dismiss() }
                }
            }
            .tint(Color.lilyAccent)
        }
        .lilyFormSheet()
        .presentationDragIndicator(.visible)
        .errorPopup(errorCenter)
        .task { await load() }
    }

    /// The voters listed once they loaded, the message's count until then, so the header never disagrees with the rows.
    private func count(for option: Poll.Option) -> Int {
        voters?.options.first { $0.id == option.id }?.voters.count ?? option.votes
    }

    @ViewBuilder private func section(for option: Poll.Option) -> some View {
        if let voters {
            let names = voters.options.first { $0.id == option.id }?.voters ?? []
            if names.isEmpty {
                Text(Copy.nobodyYet).foregroundStyle(.secondary)
            } else {
                ForEach(names) { voter in
                    HStack(spacing: DesignTokens.Spacing.md) {
                        AvatarCircle(initials: voter.name.initials, size: DesignTokens.Layout.avatarSmall, tint: .secondary)
                            .accessibilityHidden(true)
                        Text(verbatim: voter.name)
                    }
                }
            }
        }
    }

    private func load() async {
        guard let loaded = await viewModel.voters(of: message) else {
            dismiss()
            return
        }
        voters = loaded
    }
}
