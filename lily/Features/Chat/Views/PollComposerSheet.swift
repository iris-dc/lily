import SwiftUI

/// "New poll": the question, two to ten options (Add an option below them, a remove button beside each past the
/// second), Anonymous voting (on, as Telegram) and Multiple answers (off), and Send in the bar once the poll is valid
/// (`PollDraft`). Send closes the sheet: the poll goes out as a pending bubble, whose failures reach the chat's popup.
struct PollComposerSheet: View {
    let onSend: (PollDraft) -> Void
    @State private var question = ""
    @State private var options = [OptionField(), OptionField()]
    @State private var isAnonymous = true
    @State private var allowsMultipleAnswers = false
    @FocusState private var focus: Field?
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Chat.Polls

    private enum Field: Hashable {
        case question
        case option(UUID)
    }

    /// An option's field, with an id of its own so removing one keeps the others' focus and text.
    private struct OptionField: Identifiable {
        let id = UUID()
        var text = ""
    }

    private var draft: PollDraft {
        PollDraft(question: question,
                  options: options.map(\.text),
                  isAnonymous: isAnonymous,
                  allowsMultipleAnswers: allowsMultipleAnswers)
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                Form {
                    Section(Copy.question) {
                        TextField(Copy.askAQuestion, text: $question, axis: .vertical)
                            .focused($focus, equals: .question)
                            .accessibilityIdentifier(AccessibilityIdentifiers.pollQuestionField)
                    }
                    Section(Copy.options) {
                        optionFields
                        if draft.canAddOption {
                            Button(Copy.addOption, systemImage: DesignTokens.Symbols.addOption, action: addOption)
                                .accessibilityIdentifier(AccessibilityIdentifiers.pollAddOption)
                        }
                    }
                    Section {
                        Toggle(Copy.anonymousVoting, isOn: $isAnonymous)
                            .accessibilityIdentifier(AccessibilityIdentifiers.pollAnonymousToggle)
                        Toggle(Copy.multipleAnswers, isOn: $allowsMultipleAnswers)
                            .accessibilityIdentifier(AccessibilityIdentifiers.pollMultipleToggle)
                    }
                }
                .scrollContentBackground(.hidden)
                .readableColumn()
            }
            .navigationTitle(Copy.newPoll)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppBranding.Events.Create.cancel, role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.send, action: send)
                        .disabled(!draft.isValid)
                        .accessibilityIdentifier(AccessibilityIdentifiers.pollSend)
                }
            }
            .tint(Color.lilyAccent)
        }
        .lilyFormSheet()
        .presentationDragIndicator(.visible)
        .onAppear { focus = .question }
    }

    private var optionFields: some View {
        ForEach(Array($options.enumerated()), id: \.element.id) { index, $option in
            HStack {
                TextField(Copy.option(index + 1), text: $option.text)
                    .focused($focus, equals: .option(option.id))
                    .submitLabel(.next)
                    .onSubmit { focusNext(after: index) }
                    .accessibilityIdentifier(AccessibilityIdentifiers.pollOptionField(index))
                if options.count > AppConfig.Chat.Polls.minOptions {
                    Button {
                        options.removeAll { $0.id == option.id }
                    } label: {
                        Image(systemName: DesignTokens.Symbols.removeOption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Copy.removeOption)
                }
            }
        }
    }

    private func addOption() {
        let field = OptionField()
        options.append(field)
        focus = .option(field.id)
    }

    private func focusNext(after index: Int) {
        if options.indices.contains(index + 1) {
            focus = .option(options[index + 1].id)
        } else if draft.canAddOption {
            addOption()
        }
    }

    private func send() {
        guard draft.isValid else { return }
        onSend(draft)
        dismiss()
    }
}
