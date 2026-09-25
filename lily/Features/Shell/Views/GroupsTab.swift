import SwiftUI

/// The Groups tab. Its root is the one `NavigationStack` bound to `AppNavigation.groupsPath`, so a push made from
/// elsewhere in the app lands here.
struct GroupsTab: View {
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var navigation = dependencies.navigation
        NavigationStack(path: $navigation.groupsPath) {
            GroupsRootView(dependencies: dependencies)
        }
    }
}

#Preview {
    GroupsTab(dependencies: .makeMock())
}
