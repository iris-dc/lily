import Foundation

/// The profile sheet's own pushes, as values on its `NavigationPath`: a value link (an Activity row's event or
/// tournament) never resolves inside a screen pushed through `isPresented`, so the sheet pushes by value throughout,
/// like the tab stacks.
nonisolated struct SettingsDestination: Hashable {}

/// The Activity screen behind the profile root's history row.
nonisolated struct ActivityDestination: Hashable {}
