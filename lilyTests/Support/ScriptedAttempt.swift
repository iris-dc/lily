import Foundation

/// A scripted attempt: answers in order and counts how often it was asked, so a test sees exactly how many tries a
/// repeat cost. Running out of answers is a failure of its own, never a crash of the test host.
@MainActor
final class ScriptedAttempt {
    struct Exhausted: Error {}

    private var answers: [Result<Int, any Error>]
    private(set) var attempts = 0

    init(_ answers: [Result<Int, any Error>]) {
        self.answers = answers
    }

    func next() throws -> Int {
        attempts += 1
        guard !answers.isEmpty else { throw Exhausted() }
        return try answers.removeFirst().get()
    }
}
