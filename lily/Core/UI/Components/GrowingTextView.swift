import SwiftUI
import UIKit

/// A text field that grows with its text up to `maxLines` and scrolls past them, over a UIKit text view the app owns.
/// SwiftUI's multi-line `TextField` keeps its text once the keyboard has shown an inline prediction in it and the
/// binding is then cleared; here a binding change replaces the text, marked or not. Focus follows `isFocused` both
/// ways, a hardware Return asks `onReturn` whether to insert its newline (`.ignored`) or has been dealt with
/// (`.handled`), the placeholder reads as the value while the text is empty, as a `TextField`'s does, and the font
/// follows Dynamic Type. The chrome around it (padding, glass) is the caller's.
struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let maxLines: Int
    let accessibilityIdentifier: String
    let onReturn: (EventModifiers) -> KeyPress.Result

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    func makeUIView(context: Context) -> PlaceholderTextView {
        let view = PlaceholderTextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = .label
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.alwaysBounceVertical = false
        view.accessibilityIdentifier = accessibilityIdentifier
        view.accessibilityLabel = placeholder
        return view
    }

    func updateUIView(_ view: PlaceholderTextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused
        view.placeholder = placeholder
        view.onReturn = onReturn
        if view.text != text {
            // The setter drops marked text (an inline prediction, a composition) with the rest.
            view.text = text
            view.refreshPlaceholder()
        }
        syncFocus(of: view)
    }

    /// The field takes the keyboard when `isFocused` turns true (deferred: the view may not be in a window during the
    /// update) and gives it up when it turns false; the coordinator writes the user's own changes back.
    private func syncFocus(of view: PlaceholderTextView) {
        if isFocused, !view.isFirstResponder {
            Task { @MainActor in view.takeFocus() }
        } else if !isFocused, view.isFirstResponder {
            view.resignFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView view: PlaceholderTextView, context: Context) -> CGSize? {
        let lineHeight = view.font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
        // No width proposed (the ideal) or an infinite one lays the text out on one line, not one glyph per line.
        let width = proposal.width ?? .greatestFiniteMagnitude
        let fitted = view.sizeThatFits(CGSize(width: width.isFinite ? width : .greatestFiniteMagnitude,
                                              height: .greatestFiniteMagnitude))
        return CGSize(width: proposal.width ?? fitted.width,
                      height: Metrics.height(fitting: fitted.height, lineHeight: lineHeight, maxLines: maxLines))
    }

    /// The height the field takes for its text: at least one line, at most `maxLines`, then it scrolls.
    nonisolated enum Metrics {
        static func height(fitting contentHeight: CGFloat, lineHeight: CGFloat, maxLines: Int) -> CGFloat {
            min(max(contentHeight, lineHeight), lineHeight * CGFloat(max(maxLines, 1)))
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused.wrappedValue = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isFocused.wrappedValue = false
        }
    }
}

/// The text view behind `GrowingTextView`: a placeholder label while the text is empty, the placeholder as the
/// accessibility value then, a hardware Return routed through `onReturn` (as key commands, which take the key before
/// the text system inserts it; the software keyboard's Return never passes here and keeps inserting newlines), and a
/// keyboard that does not come back by itself after the field left the window.
final class PlaceholderTextView: UITextView {
    var placeholder = "" {
        didSet { placeholderLabel.text = placeholder }
    }
    var onReturn: (EventModifiers) -> KeyPress.Result = { _ in .ignored }

    private let placeholderLabel = UILabel()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        placeholderLabel.textColor = .secondaryLabel
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.isAccessibilityElement = false
        addSubview(placeholderLabel)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshPlaceholder),
                                               name: UITextView.textDidChangeNotification,
                                               object: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PlaceholderTextView is built in code")
    }

    /// The placeholder shows while the text is empty: after the user's edits (the notification), a programmatic set
    /// (`GrowingTextView.updateUIView`) and every layout.
    @objc func refreshPlaceholder() {
        placeholderLabel.isHidden = !text.isEmpty
    }

    override var font: UIFont? {
        didSet { placeholderLabel.font = font }
    }

    override var accessibilityValue: String? {
        get { text.isEmpty ? placeholder : text }
        set { super.accessibilityValue = newValue }
    }

    /// Whether the field may take the keyboard. UIKit hands a field that was editing the keyboard back as its screen
    /// returns, before SwiftUI has laid the screen out around it: a field that left the window takes the keyboard again
    /// only at a touch (or a pointer over it), an accessibility activation, or its owner's word.
    private var acceptsFocus = true

    override var canBecomeFirstResponder: Bool {
        acceptsFocus && super.canBecomeFirstResponder
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil { acceptsFocus = false }
        super.willMove(toWindow: newWindow)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if hit != nil { acceptsFocus = true }
        return hit
    }

    override func accessibilityActivate() -> Bool {
        acceptsFocus = true
        return super.accessibilityActivate()
    }

    /// The owner's word: the keyboard asked for through `GrowingTextView.isFocused`.
    func takeFocus() {
        acceptsFocus = true
        becomeFirstResponder()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshPlaceholder()
        placeholderLabel.frame = CGRect(x: textContainerInset.left + textContainer.lineFragmentPadding,
                                        y: textContainerInset.top,
                                        width: bounds.width - textContainerInset.left - textContainerInset.right,
                                        height: placeholderLabel.font?.lineHeight ?? bounds.height)
    }

    /// Return and the keypad's Enter, plain and with Shift; a key command matches its flags exactly.
    static let returnKeyFlags: [UIKeyModifierFlags] = [[], .shift, .numericPad, [.shift, .numericPad]]

    override var keyCommands: [UIKeyCommand]? {
        let returns = Self.returnKeyFlags.map { flags in
            UIKeyCommand(input: "\r", modifierFlags: flags, action: #selector(returnPressed(_:)))
        }
        returns.forEach { $0.wantsPriorityOverSystemBehavior = true }
        return (super.keyCommands ?? []) + returns
    }

    /// Return while a composition is marked (an IME's candidate) confirms it, as the text system would have.
    @objc private func returnPressed(_ command: UIKeyCommand) {
        guard markedTextRange == nil else {
            unmarkText()
            return
        }
        if onReturn(EventModifiers(command.modifierFlags)) == .ignored {
            insertText("\n")
        }
    }
}

nonisolated extension EventModifiers {
    /// The SwiftUI modifiers of a UIKit key event.
    init(_ flags: UIKeyModifierFlags) {
        var modifiers: EventModifiers = []
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.alternate) { modifiers.insert(.option) }
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.alphaShift) { modifiers.insert(.capsLock) }
        if flags.contains(.numericPad) { modifiers.insert(.numericPad) }
        self = modifiers
    }
}
