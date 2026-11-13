import SwiftUI

/// The name field and the map row of every form that asks for a spot (event, group, tournament, match schedule).
/// The name row is `PlaceNameField` without its suggestion machinery; a form that offers suggestions (the event
/// form) composes the parts itself. No `Section` of its own: the forms keep their header and footer.
struct PlaceFields<Field: Hashable>: View {
    @Binding var name: String
    @Binding var coordinate: Coordinate?
    let placeholder: String
    let nameIdentifier: String
    let pickerIdentifier: String
    /// The optional detail line between the name and the map row; `nil` keeps the form without one (the match
    /// schedule has no detail to store).
    let detail: Detail?
    /// Whether the draft's place really was chosen; the map row reads as the explicit alternative until it is.
    let placeChosen: Bool
    /// The shared marker under the name field, exactly while the caller's rules make the place optional (the group
    /// form's private visibility, like the wizard's group place page).
    let nameMarked: Bool
    let focus: FocusState<Field?>.Binding?
    let focusValue: Field?

    /// The detail line's binding and identifier, one argument so the inits stay within the parameter rule.
    struct Detail {
        let text: Binding<String>
        let identifier: String
    }

    init(name: Binding<String>,
         coordinate: Binding<Coordinate?>,
         placeholder: String = AppBranding.Events.Create.locationNamePlaceholder,
         nameIdentifier: String,
         pickerIdentifier: String,
         detail: Detail? = nil,
         placeChosen: Bool = true,
         nameMarked: Bool = false,
         focus: FocusState<Field?>.Binding,
         equals focusValue: Field) {
        _name = name
        _coordinate = coordinate
        self.placeholder = placeholder
        self.nameIdentifier = nameIdentifier
        self.pickerIdentifier = pickerIdentifier
        self.detail = detail
        self.placeChosen = placeChosen
        self.nameMarked = nameMarked
        self.focus = focus
        self.focusValue = focusValue
    }

    var body: some View {
        nameRow
        if let detail {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                PlaceDetailField(detail: detail.text, identifier: detail.identifier)
                OptionalMarker()
            }
        }
        PlacePickerRow(coordinate: $coordinate, placeChosen: placeChosen)
            .accessibilityIdentifier(pickerIdentifier)
    }

    /// The name capsule, wearing the shared marker below it while the place is optional.
    @ViewBuilder private var nameRow: some View {
        if nameMarked {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                nameField
                OptionalMarker()
            }
        } else {
            nameField
        }
    }

    @ViewBuilder
    private var nameField: some View {
        if let focus, let focusValue {
            PlaceNameField(name: $name,
                           placeholder: placeholder,
                           identifier: nameIdentifier,
                           focus: focus,
                           equals: focusValue)
        } else {
            PlaceNameField<Never>(name: $name, placeholder: placeholder, identifier: nameIdentifier)
        }
    }
}

extension PlaceFields where Field == Never {
    /// The fields of a form that moves no focus of its own.
    init(name: Binding<String>,
         coordinate: Binding<Coordinate?>,
         placeholder: String = AppBranding.Events.Create.locationNamePlaceholder,
         nameIdentifier: String,
         pickerIdentifier: String,
         detail: Detail? = nil,
         placeChosen: Bool = true,
         nameMarked: Bool = false) {
        _name = name
        _coordinate = coordinate
        self.placeholder = placeholder
        self.nameIdentifier = nameIdentifier
        self.pickerIdentifier = pickerIdentifier
        self.detail = detail
        self.placeChosen = placeChosen
        self.nameMarked = nameMarked
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
