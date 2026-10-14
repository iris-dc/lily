import Observation

/// What `DraftSheet` needs from a create or edit view model: the draft's issues for the hints, the request's state for
/// the bar, and the two calls the shell makes on the model's behalf.
protocol DraftSubmitting: AnyObject, Observable {
    associatedtype Issue: Equatable

    var issues: [Issue] { get }
    var isSubmitting: Bool { get }
    var canSubmit: Bool { get }
    /// The backend answered; the sheet closes.
    var isDone: Bool { get }
    /// Runs once when the sheet appears, before the user types: a create proposes the device's position as the spot
    /// (and reads the groups the caller may host in); an edit has nothing to fetch, so the default does nothing.
    func prepare() async
    func submit() async
}

extension DraftSubmitting {
    // Listed in the protocol body so that a conforming type's own `prepare()` is the one the sheet calls; as an
    // extension method alone, `DraftSheet`'s call on `Model` would resolve statically to this empty default.
    func prepare() async {}

    /// The first of `candidates` the draft has, for the hint under the section they concern.
    func issue(for candidates: Issue...) -> Issue? {
        issues.first(of: candidates)
    }
}
