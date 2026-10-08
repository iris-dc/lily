import SwiftUI

/// The field and the send button at the bottom of a chat, on glass, with the attach "+" leading the field while the
/// backend takes attachments. The field grows to five lines, a counter shows once the text nears the limit, and after
/// a 429 the button stays closed while a caption counts the cooldown down. While the draft answers a message,
/// `ReplyPreviewBar` sits above the field and the field takes focus; while pictures are picked, `AttachmentStrip` does.
/// On a hardware keyboard Return sends and Shift+Return starts a new line (`ReturnKeyPolicy`).
struct MessageComposer: View {
    @Bindable var viewModel: ChatViewModel
    /// Advanced once a second while the cooldown runs, so the caption and the button follow the clock.
    @State private var tick = 0
    @FocusState private var isFieldFocused: Bool

    private typealias Copy = AppBranding.Chat

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            GlassEffectContainer {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    if let quote = viewModel.replyTarget {
                        ReplyPreviewBar(quote: quote) { viewModel.cancelReply() }
                    }
                    if !viewModel.attachments.isEmpty {
                        AttachmentStrip(attachments: viewModel.attachments)
                    }
                    HStack(alignment: .bottom, spacing: DesignTokens.Spacing.sm) {
                        if viewModel.attachmentsEnabled {
                            AttachmentMenuButton(attachments: viewModel.attachments)
                        }
                        TextField(Copy.placeholder, text: $viewModel.draft.text, axis: .vertical)
                            .lineLimit(DesignTokens.Layout.multilineFieldLines)
                            .lilyMultilineField()
                            .focused($isFieldFocused)
                            .onKeyPress(keys: [.return], action: handleReturn)
                            .accessibilityIdentifier(AccessibilityIdentifiers.chatComposer)
                        sendButton
                    }
                }
            }
            if let caption = caption(tick: tick) {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DesignTokens.Spacing.lg)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .task(id: viewModel.cooldownUntil) { await countDown() }
        .onChange(of: viewModel.replyTarget) {
            if viewModel.replyTarget != nil { isFieldFocused = true }
        }
    }

    /// A hardware Return: `.ignored` lets the field insert its newline; `.handled` keeps it out of the text.
    private func handleReturn(_ press: KeyPress) -> KeyPress.Result {
        switch ReturnKeyPolicy.action(modifiers: press.modifiers, canSend: viewModel.canSend) {
        case .newline:
            return .ignored
        case .send:
            Task { await viewModel.send() }
            return .handled
        case .nothing:
            return .handled
        }
    }

    private var sendButton: some View {
        Button {
            Task { await viewModel.send() }
        } label: {
            Image(systemName: DesignTokens.Symbols.send)
        }
        .lilyIconButton()
        .disabled(!viewModel.canSend)
        .accessibilityLabel(Copy.send)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatSend)
    }

    /// The cooldown wins over the counter; `tick` is read so the caption is re-evaluated as the clock moves.
    private func caption(tick: Int) -> String? {
        if let seconds = viewModel.cooldownSeconds {
            return Copy.slowDown(seconds: seconds)
        }
        if viewModel.draft.text.wireLength >= AppConfig.Chat.counterThreshold {
            return Copy.remaining(viewModel.draft.remaining)
        }
        return nil
    }

    private func countDown() async {
        while viewModel.isCoolingDown, !Task.isCancelled {
            try? await Task.sleep(for: AppConfig.Chat.cooldownTick)
            tick += 1
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    ContentScreen {
        VStack {
            Spacer()
            MessageComposer(viewModel: dependencies.makeChatViewModel(for: MockGroupFixtures.make(now: .now)[0]))
        }
    }
}
