import SwiftUI

/// The one list of levels a host can ask for or a filter narrows to: "Any level" over `SkillLevel.known`, so an
/// unknown level is never offered. Callers style it from outside (`pickerStyle` and `labelsHidden` propagate through
/// the environment).
struct SkillLevelPicker: View {
    @Binding var selection: SkillLevel?

    var body: some View {
        Picker(AppBranding.Events.levelLabel, selection: $selection) {
            Text(AppBranding.Events.anyLevel).tag(SkillLevel?.none)
            ForEach(SkillLevel.known, id: \.self) { level in
                Text(level.displayName).tag(SkillLevel?.some(level))
            }
        }
    }
}

#Preview {
    Form {
        SkillLevelPicker(selection: .constant(.intermediate))
    }
}
