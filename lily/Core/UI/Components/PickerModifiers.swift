import SwiftUI

extension View {
    /// A menu picker in a form (the Group and Level rows of the event form, the tournament form's Group row, the filter
    /// panel's Level row). The control colours its value and chevron from the tint, which is the accent in every form
    /// sheet, and the accent reads at about 3:1 as small text; `.secondary` keeps both legible while the row's title
    /// stays primary and the menu's items keep the system look.
    func lilyMenuPicker() -> some View {
        pickerStyle(.menu)
            .tint(.secondary)
    }
}
