import SwiftUI

/// Who voted for what in a public poll: a section per option with its voters in the order they voted. A failed load
/// reaches the popup this sheet mounts and closes the sheet.
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
                            Text(verbatim: option.text)
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
        .accessibilityIdentifier(AccessibilityIdentifiers.pollVotersSheet)
        .task { await load() }
    }

    @ViewBuilder private func section(for option: Poll.Option) -> some View {
        if let voters {
            let names = voters.options.first { $0.id == option.id }?.voters ?? []
            if names.isEmpty {
                Text(Copy.nobodyYet).foregroundStyle(.secondary)
            } else {
                ForEach(names) { voter in
                    Label(voter.name, systemImage: DesignTokens.Symbols.profile)
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
