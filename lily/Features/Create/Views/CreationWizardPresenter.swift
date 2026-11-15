import SwiftUI

/// A screen's presented item that may be the creation wizard: the shared presenter splits the wizard between its two
/// hosts and leaves every other item to the screen's own sheet content.
protocol WizardPresentable: Identifiable {
    var isWizard: Bool { get }
}

extension WizardPresentable {
    /// Whether the item, presented, rides the full-screen cover: only the wizard, and only on a compact width; any
    /// other width keeps it a sheet, sized like every form.
    func presentsAsCover(on layoutMode: LayoutMode) -> Bool {
        isWizard && layoutMode == .compact
    }
}

/// The presented item of a screen whose only sheet is the wizard.
enum WizardOnlySheet: String, Identifiable, WizardPresentable {
    case wizard

    var id: String { rawValue }
    var isWizard: Bool { true }
}

extension View {
    /// Hosts the creation wizard over a screen: a full-screen cover on a compact width, a form sheet elsewhere, both
    /// over the one presented item, so a width-class change mid-flow re-hosts the same flow instead of destroying it.
    /// `sheetContent` draws the screen's other items (the wizard never reaches it). `onDismissed` runs on a real
    /// dismissal alone — the item cleared through a presenter's binding, never a re-host — the one moment the flow's
    /// close may be booked (the abandoned log, once and never after a create).
    func creationWizardPresenter<Item: WizardPresentable, SheetContent: View>(
        item: Binding<Item?>,
        model: AppCreationWizardModel?,
        errorCenter: ErrorCenter,
        onDismissed: @escaping () -> Void,
        @ViewBuilder sheetContent: @escaping (Item) -> SheetContent
    ) -> some View {
        modifier(CreationWizardPresenter(item: item,
                                         model: model,
                                         errorCenter: errorCenter,
                                         onDismissed: onDismissed,
                                         sheetContent: sheetContent))
    }

    /// The host for a screen with no sheets of its own.
    func creationWizardPresenter(item: Binding<WizardOnlySheet?>,
                                 model: AppCreationWizardModel?,
                                 errorCenter: ErrorCenter,
                                 onDismissed: @escaping () -> Void) -> some View {
        creationWizardPresenter(item: item,
                                model: model,
                                errorCenter: errorCenter,
                                onDismissed: onDismissed) { _ in EmptyView() }
    }
}

private struct CreationWizardPresenter<Item: WizardPresentable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let model: AppCreationWizardModel?
    let errorCenter: ErrorCenter
    let onDismissed: () -> Void
    let sheetContent: (Item) -> SheetContent
    @Environment(\.layoutMode) private var layoutMode

    func body(content: Content) -> some View {
        content
            .sheet(item: sheetItem, onDismiss: noteRealDismissal) { presented in
                if presented.isWizard {
                    // The grabber is hidden: the wizard refuses the swipe while the draft is dirty, not a transient lock.
                    wizard.lilyFormSheet()
                        .presentationDragIndicator(.hidden)
                } else {
                    sheetContent(presented)
                }
            }
            .fullScreenCover(item: coverItem, onDismiss: noteRealDismissal) { _ in wizard }
    }

    private var coverClaims: Bool { item?.presentsAsCover(on: layoutMode) ?? false }

    /// The two presenters split the item between them: each shows it only while the other does not claim it.
    private var sheetItem: Binding<Item?> {
        Binding(get: { coverClaims ? nil : item }, set: { item = $0 })
    }

    private var coverItem: Binding<Item?> {
        Binding(get: { coverClaims ? item : nil }, set: { item = $0 })
    }

    /// The wizard both presenters host; it mounts its own popup and dismissal rules, so the presenters add sizing only.
    @ViewBuilder private var wizard: some View {
        if let model {
            CreationWizardView(model: model, errorCenter: errorCenter)
        }
    }

    private func noteRealDismissal() {
        guard item == nil else { return }
        onDismissed()
    }
}
