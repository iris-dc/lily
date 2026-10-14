import SwiftUI

/// The name field and the map row of every form that asks for a spot (event, group, tournament, match schedule).
/// No `Section` of its own: the forms keep their header and footer.
struct PlaceFields<Field: Hashable>: View {
    @Binding var name: String
    @Binding var coordinate: Coordinate?
    let placeholder: String
    let nameIdentifier: String
    let pickerIdentifier: String
    let focus: FocusState<Field?>.Binding?
    let focusValue: Field?

    init(name: Binding<String>,
         coordinate: Binding<Coordinate?>,
         placeholder: String = AppBranding.Events.Create.locationNamePlaceholder,
         nameIdentifier: String,
         pickerIdentifier: String,
         focus: FocusState<Field?>.Binding,
         equals focusValue: Field) {
        _name = name
        _coordinate = coordinate
        self.placeholder = placeholder
        self.nameIdentifier = nameIdentifier
        self.pickerIdentifier = pickerIdentifier
        self.focus = focus
        self.focusValue = focusValue
    }

    var body: some View {
        nameField
        PlacePickerRow(coordinate: $coordinate)
            .accessibilityIdentifier(pickerIdentifier)
    }

    @ViewBuilder
    private var nameField: some View {
        let field = TextField(placeholder, text: $name)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .accessibilityIdentifier(nameIdentifier)
        if let focus, let focusValue {
            field.focused(focus, equals: focusValue)
        } else {
            field
        }
    }
}

extension PlaceFields where Field == Never {
    /// The fields of a form that moves no focus of its own.
    init(name: Binding<String>,
         coordinate: Binding<Coordinate?>,
         placeholder: String = AppBranding.Events.Create.locationNamePlaceholder,
         nameIdentifier: String,
         pickerIdentifier: String) {
        _name = name
        _coordinate = coordinate
        self.placeholder = placeholder
        self.nameIdentifier = nameIdentifier
        self.pickerIdentifier = pickerIdentifier
        focus = nil
        focusValue = nil
    }
}

#Preview {
    @Previewable @State var name = ""
    @Previewable @State var coordinate: Coordinate? = AppConfig.Location.mockCenter
    NavigationStack {
        Form {
            Section(AppBranding.Events.Create.whereSection) {
                PlaceFields(name: $name,
                            coordinate: $coordinate,
                            nameIdentifier: AccessibilityIdentifiers.createLocationName,
                            pickerIdentifier: AccessibilityIdentifiers.createPickOnMap)
            }
        }
    }
}
