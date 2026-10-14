import SwiftUI
import Testing
@testable import lily

/// The optional-to-Bool bridge a confirmation dialog is driven by: true while the item is set, cleared by a
/// dismissal, never set by anything else.
@MainActor
struct BindingIsPresentTests {
    @MainActor private final class OptionalBox {
        var value: Int?
    }

    private func binding(over box: OptionalBox) -> Binding<Int?> {
        Binding(get: { box.value }, set: { box.value = $0 })
    }

    @Test func isTrueWhileTheValueIsSet() {
        let box = OptionalBox()
        box.value = 3
        let isPresent = binding(over: box).isPresent()

        #expect(isPresent.wrappedValue)
        box.value = nil
        #expect(!isPresent.wrappedValue)
    }

    @Test func settingItFalseClearsTheValue() {
        let box = OptionalBox()
        box.value = 3

        binding(over: box).isPresent().wrappedValue = false

        #expect(box.value == nil)
    }

    @Test func settingItTrueLeavesTheValueAlone() {
        let box = OptionalBox()
        let isPresent = binding(over: box).isPresent()

        isPresent.wrappedValue = true
        #expect(box.value == nil)

        box.value = 3
        isPresent.wrappedValue = true
        #expect(box.value == 3)
    }
}
