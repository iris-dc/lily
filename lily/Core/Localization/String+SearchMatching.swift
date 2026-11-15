import Foundation

/// Whether this string answers a search the user typed: an empty or blank query matches everything; otherwise the
/// string must contain it, case- and diacritic-insensitive ("Futbol" finds "Fútbol"), folded by the app's locale
/// (`AppLocale`), not the system's, so the fold matches the language the labels read in. The one match rule of the
/// type pickers (the wizard's grid and the edit form's compact chips).
nonisolated extension String {
    func matchesSearch(_ query: String) -> Bool {
        let query = query.trimmed
        guard !query.isEmpty else { return true }
        return range(of: query, options: [.caseInsensitive, .diacriticInsensitive], locale: AppLocale.locale) != nil
    }
}
