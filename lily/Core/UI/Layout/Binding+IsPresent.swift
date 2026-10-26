import SwiftUI

extension Binding {
    /// True while the optional holds a value; set false it clears the value, set true it changes nothing (a dialog is
    /// only ever dismissed through it). What `confirmationDialog(presenting:)` and `alert(presenting:)` need, since
    /// SwiftUI has no `item:` form of either.
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

    /// The same with a message under the title. A separate overload, so a dialog without one still calls SwiftUI's
    /// message-less form.
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

    /// An alert driven by an optional item, like `sheet(item:)`: shown in the middle of the screen while `item` holds a
    /// value, titled from it, its buttons and message built from it, and the item cleared when it is dismissed. For a
    /// question asked from a toolbar menu, where a confirmation dialog would open as a popover at the menu's corner.
    func alert<Item, Actions: View, Message: View>(
        item: Binding<Item?>,
        title: (Item) -> String,
        @ViewBuilder actions: @escaping (Item) -> Actions,
        @ViewBuilder message: @escaping (Item) -> Message
    ) -> some View {
        alert(item.wrappedValue.map(title) ?? "",
              isPresented: item.isPresent(),
              presenting: item.wrappedValue,
              actions: actions,
              message: message)
    }
}
