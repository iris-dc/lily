import SwiftUI

extension Binding {
    /// True while the optional holds a value; set false it clears the value, set true it changes nothing (a dialog is
    /// only ever dismissed through it). What `confirmationDialog(presenting:)` needs, since SwiftUI has no `item:`
    /// form of it.
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(get: { wrappedValue != nil }, set: { if !$0 { wrappedValue = nil } })
    }
}

extension View {
    /// A confirmation dialog driven by an optional item, like `sheet(item:)`: shown while `item` holds a value, titled
    /// from it, its buttons built from it, and the item cleared when the dialog is dismissed.
    func confirmationDialog<Item, Actions: View>(
        item: Binding<Item?>,
        title: (Item) -> String,
        @ViewBuilder actions: @escaping (Item) -> Actions
    ) -> some View {
        confirmationDialog(item.wrappedValue.map(title) ?? "",
                           isPresented: item.isPresent(),
                           titleVisibility: .visible,
                           presenting: item.wrappedValue,
                           actions: actions)
    }

    /// The same with a message under the title. A separate overload, so a dialog without one keeps calling SwiftUI's
    /// message-less form and renders as before.
    func confirmationDialog<Item, Actions: View, Message: View>(
        item: Binding<Item?>,
        title: (Item) -> String,
        @ViewBuilder actions: @escaping (Item) -> Actions,
        @ViewBuilder message: @escaping (Item) -> Message
    ) -> some View {
        confirmationDialog(item.wrappedValue.map(title) ?? "",
                           isPresented: item.isPresent(),
                           titleVisibility: .visible,
                           presenting: item.wrappedValue,
                           actions: actions,
                           message: message)
    }
}
